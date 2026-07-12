import Foundation
import Observation
import StoreKit

@Observable
@MainActor
final class SubscriptionStore {
    static let monthlyId = "glpill.pro.monthly"
    static let yearlyId = "glpill.pro.yearly"
    static let productIds: Set<String> = [monthlyId, yearlyId]

    private let provider: EntitlementProviding
    private(set) var state: EntitlementState = .unknown
    private(set) var products: [Product] = []
    var lastError: String?

    var isUnlocked: Bool { state == .active }

    init(provider: EntitlementProviding = StoreKitEntitlementProvider()) {
        self.provider = provider
    }

    func refresh() async {
        state = await provider.currentState()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.productIds)
                .sorted { $0.price < $1.price }
        } catch {
            lastError = "Could not load subscription options. Check your connection and try again."
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refresh()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed. You have not been charged — please try again."
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    /// Long-lived listener for transaction updates (renewals, refunds, Ask to Buy).
    func startTransactionListener() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
    }
}
