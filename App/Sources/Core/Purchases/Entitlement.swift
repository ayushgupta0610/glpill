import Foundation
import StoreKit

enum EntitlementState: Equatable {
    case unknown
    case locked
    case active
}

/// Outcome of a direct, un-raced entitlement check (used by `restore()`).
/// Distinguishes a definitive "no active subscription" from an inconclusive
/// check that couldn't complete — so a real subscriber on a cold connection
/// isn't wrongly told nothing exists.
enum EntitlementCheck: Equatable {
    case active
    case none
    case inconclusive
}

protocol EntitlementProviding {
    func currentState() async -> EntitlementState
    /// Checks entitlements directly with no timeout race. Returns `.none` only
    /// when the check completed and definitively found no matching entitlement.
    func directCheck() async -> EntitlementCheck
}

#if DEBUG
/// UI-test override activated by the -uiTestUnlocked launch argument.
struct AlwaysActiveProvider: EntitlementProviding {
    func currentState() async -> EntitlementState { .active }
    func directCheck() async -> EntitlementCheck { .active }
}
#endif

struct StoreKitEntitlementProvider: EntitlementProviding {
    func currentState() async -> EntitlementState {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               SubscriptionStore.productIds.contains(transaction.productID) {
                return .active
            }
        }
        return .locked
    }

    func directCheck() async -> EntitlementCheck {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               SubscriptionStore.productIds.contains(transaction.productID) {
                return .active
            }
        }
        // The sequence completed without a matching verified entitlement.
        return .none
    }
}
