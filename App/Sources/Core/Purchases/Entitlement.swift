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
