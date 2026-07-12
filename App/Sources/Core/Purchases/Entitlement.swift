import Foundation
import StoreKit

enum EntitlementState: Equatable {
    case unknown
    case locked
    case active
}

protocol EntitlementProviding {
    func currentState() async -> EntitlementState
}

#if DEBUG
/// UI-test override activated by the -uiTestUnlocked launch argument.
struct AlwaysActiveProvider: EntitlementProviding {
    func currentState() async -> EntitlementState { .active }
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
}
