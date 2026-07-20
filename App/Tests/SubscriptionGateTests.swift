import XCTest
@testable import GLPill

private struct MockProvider: EntitlementProviding {
    let state: EntitlementState
    func currentState() async -> EntitlementState { state }
}

private final class MutableProvider: EntitlementProviding, @unchecked Sendable {
    var current: EntitlementState
    init(_ current: EntitlementState) { self.current = current }
    func currentState() async -> EntitlementState { current }
}

/// Simulates a stalled entitlement lookup (cold storekitd, no network) that
/// never returns within the test's lifetime.
private struct NeverResolvingProvider: EntitlementProviding {
    func currentState() async -> EntitlementState {
        try? await Task.sleep(for: .seconds(3600))
        return .active
    }
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
}
