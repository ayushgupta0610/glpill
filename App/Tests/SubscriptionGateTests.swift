import XCTest
@testable import GLPill

private struct MockProvider: EntitlementProviding {
    let state: EntitlementState
    func currentState() async -> EntitlementState { state }
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
}
