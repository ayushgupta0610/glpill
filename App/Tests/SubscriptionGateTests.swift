import XCTest
@testable import GLPill

private extension EntitlementState {
    var asCheck: EntitlementCheck {
        switch self {
        case .active: return .active
        case .locked: return .none
        case .unknown: return .inconclusive
        }
    }
}

private struct MockProvider: EntitlementProviding {
    let state: EntitlementState
    func currentState() async -> EntitlementState { state }
    func directCheck() async -> EntitlementCheck { state.asCheck }
}

private final class MutableProvider: EntitlementProviding, @unchecked Sendable {
    var current: EntitlementState
    init(_ current: EntitlementState) { self.current = current }
    func currentState() async -> EntitlementState { current }
    func directCheck() async -> EntitlementCheck { current.asCheck }
}

/// Restore-path provider: the timeout-raced `currentState()` fails closed to
/// `.locked` (cold connection), but the direct check reports the truth.
private struct RestoreProvider: EntitlementProviding {
    let raced: EntitlementState
    let direct: EntitlementCheck
    func currentState() async -> EntitlementState { raced }
    func directCheck() async -> EntitlementCheck { direct }
}

/// Simulates a stalled entitlement lookup (cold storekitd, no network) that
/// never returns within the test's lifetime.
private struct NeverResolvingProvider: EntitlementProviding {
    func currentState() async -> EntitlementState {
        try? await Task.sleep(for: .seconds(3600))
        return .active
    }
    func directCheck() async -> EntitlementCheck { .inconclusive }
}

/// Simulates a provider that ignores cancellation entirely — ie. a real hang,
/// not just a long `Task.sleep` (which IS cooperatively cancellable and would
/// pass even a naive timeout implementation). This never checks
/// `Task.isCancelled` and never awaits a cancellable suspension point, so a
/// `refresh()` implementation that structurally awaits this call (e.g. via a
/// bare `withTaskGroup`, which implicitly awaits its losing child before
/// returning) would hang forever. Only an implementation where the timeout
/// path never awaits this provider at all can win the race.
private struct NonCancellableStallProvider: EntitlementProviding {
    func currentState() async -> EntitlementState {
        let deadline = Date().addingTimeInterval(3600)
        while Date() < deadline {
            // Busy-poll instead of Task.sleep so cancellation is never observed.
            await Task.yield()
        }
        return .active
    }
    func directCheck() async -> EntitlementCheck { .inconclusive }
}

final class SubscriptionGateTests: XCTestCase {
    @MainActor
    func testInitialStateIsUnknownAndLocked() {
        let store = SubscriptionStore(provider: MockProvider(state: .locked))
        XCTAssertEqual(store.state, .unknown)
        XCTAssertFalse(store.isUnlocked)
    }

    @MainActor
    func testRefreshWithActiveEntitlementUnlocks() async {
        let store = SubscriptionStore(provider: MockProvider(state: .active))
        await store.refresh()
        XCTAssertEqual(store.state, .active)
        XCTAssertTrue(store.isUnlocked)
    }

    @MainActor
    func testRefreshWithNoEntitlementLocks() async {
        let store = SubscriptionStore(provider: MockProvider(state: .locked))
        await store.refresh()
        XCTAssertEqual(store.state, .locked)
        XCTAssertFalse(store.isUnlocked)
    }

    // A verified purchase must unlock immediately, without waiting on a
    // (possibly-lagging) entitlements re-query. Reproduces "purchase succeeded
    // but the app stayed on the paywall."
    @MainActor
    func testVerifiedPurchaseOfOurProductUnlocksImmediately() {
        let store = SubscriptionStore(provider: MockProvider(state: .locked))
        store.recordVerifiedPurchase(productID: SubscriptionStore.monthlyId)
        XCTAssertTrue(store.isUnlocked)
    }

    @MainActor
    func testVerifiedPurchaseOfUnknownProductDoesNotUnlock() {
        let store = SubscriptionStore(provider: MockProvider(state: .locked))
        store.recordVerifiedPurchase(productID: "com.someone.else.pro")
        XCTAssertFalse(store.isUnlocked)
    }

    // A live downgrade (refund/expiry) should lock the app AND explain why, so the
    // user isn't silently kicked to the paywall.
    @MainActor
    func testLiveDowngradeSetsEndedMessage() async {
        let provider = MutableProvider(.active)
        let store = SubscriptionStore(provider: provider)
        await store.refresh()                 // unknown -> active
        XCTAssertTrue(store.isUnlocked)
        XCTAssertNil(store.lastError)
        provider.current = .locked
        await store.refresh()                 // active -> locked
        XCTAssertFalse(store.isUnlocked)
        XCTAssertNotNil(store.lastError)
    }

    @MainActor
    func testColdStartLockedHasNoEndedMessage() async {
        let store = SubscriptionStore(provider: MutableProvider(.locked))
        await store.refresh()                 // unknown -> locked (not a downgrade)
        XCTAssertNil(store.lastError)
    }

    // CRITICAL: reproduces "the paywall didn't come." If the entitlement
    // provider stalls (cold storekitd, no network), refresh() must still fail
    // CLOSED to .locked within the timeout instead of leaving state .unknown
    // forever, which would trap the user on the loading splash.
    @MainActor
    func testStalledProviderFailsClosedToLockedAfterTimeout() async {
        let store = SubscriptionStore(provider: NeverResolvingProvider(), refreshTimeout: .milliseconds(50))
        await store.refresh()
        XCTAssertEqual(store.state, .locked)
        XCTAssertFalse(store.isUnlocked)
    }

    // Regression: a normally-resolving provider that answers well within the
    // timeout must still yield the correct (non-forced) state.
    @MainActor
    func testFastResolvingProviderIsUnaffectedByTimeout() async {
        let store = SubscriptionStore(provider: MockProvider(state: .active), refreshTimeout: .milliseconds(50))
        await store.refresh()
        XCTAssertEqual(store.state, .active)
        XCTAssertTrue(store.isUnlocked)
    }

    // CRITICAL: reproduces the case where the provider doesn't just take a long
    // time — it ignores cancellation outright (a busy-poll loop, never checking
    // `Task.isCancelled` or awaiting a cancellable suspension point). A `refresh()`
    // built on a bare `withTaskGroup` would implicitly await this hung child at
    // group-exit and never return. `refresh()` must still return, and fail closed
    // to `.locked`, within (approximately) `refreshTimeout` regardless.
    @MainActor
    func testNonCancellableStallProviderStillReturnsAndFailsClosed() async throws {
        let store = SubscriptionStore(provider: NonCancellableStallProvider(), refreshTimeout: .milliseconds(50))

        let clock = ContinuousClock()
        let start = clock.now
        await store.refresh()
        let elapsed = start.duration(to: clock.now)

        XCTAssertEqual(store.state, .locked)
        XCTAssertFalse(store.isUnlocked)
        XCTAssertLessThan(elapsed, .seconds(2), "refresh() must return promptly even when the provider ignores cancellation")
    }

    // CRITICAL (D2): a real subscriber on a cold connection where the raced
    // lookup fails closed to .locked must still be unlocked by restore()'s
    // DIRECT entitlement check — no false "no subscription found".
    @MainActor
    func testRestoreUnlocksWhenDirectCheckFindsActiveDespiteRacedTimeout() async {
        let store = SubscriptionStore(
            provider: RestoreProvider(raced: .locked, direct: .active),
            refreshTimeout: .milliseconds(50),
            syncAppStore: {}
        )
        await store.restore()
        XCTAssertTrue(store.isUnlocked)
        XCTAssertNil(store.lastError)
    }

    // Only report "none found" when the direct check DEFINITIVELY finds nothing.
    @MainActor
    func testRestoreReportsNoneWhenDirectCheckDefinitivelyEmpty() async {
        let store = SubscriptionStore(provider: RestoreProvider(raced: .locked, direct: .none), syncAppStore: {})
        await store.restore()
        XCTAssertFalse(store.isUnlocked)
        XCTAssertEqual(store.lastError, "No active subscription found to restore.")
    }

    // An inconclusive direct check must NOT claim "none found" — distinct message.
    @MainActor
    func testRestoreReportsInconclusiveDistinctlyWhenDirectCheckCantComplete() async {
        let store = SubscriptionStore(provider: RestoreProvider(raced: .locked, direct: .inconclusive), syncAppStore: {})
        await store.restore()
        XCTAssertFalse(store.isUnlocked)
        XCTAssertEqual(store.lastError, "Couldn't confirm your subscription — check your connection and try again.")
    }
}
