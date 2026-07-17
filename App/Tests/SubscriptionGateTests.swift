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
}
