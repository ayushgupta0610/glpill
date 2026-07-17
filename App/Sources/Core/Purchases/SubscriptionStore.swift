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
    private(set) var restoring = false
    var lastError: String?

    var isUnlocked: Bool { state == .active }

    init(provider: EntitlementProviding = StoreKitEntitlementProvider()) {
        self.provider = provider
    }

    func refresh() async {
        let previous = state
        let next = await provider.currentState()
        state = next
        // A live downgrade (refund / expiry / lapse) arrives via the transaction
        // listener. Explain it so being sent to the paywall doesn't look like the
        // app reset or lost data.
        if previous == .active && next != .active {
            lastError = "Your subscription has ended. Renew to keep using GLPill."
        }
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
        lastError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(.verified(let transaction)):
                await transaction.finish()
                // Unlock immediately from the verified purchase. Re-querying
                // Transaction.currentEntitlements right after a purchase can lag
                // a beat and return .locked, leaving the user stuck on the paywall
                // despite a successful purchase.
                recordVerifiedPurchase(productID: transaction.productID)
                if !isUnlocked { await refresh() }
            case .success(.unverified):
                // Signature check failed — don't unlock (security), but never leave
                // the user silently stuck after a charge.
                lastError = "We couldn't verify your purchase. If you were charged, tap Restore Purchases or contact support."
            case .pending:
                // Ask to Buy / Strong Customer Authentication — arrives later via the
                // transaction listener.
                lastError = "Your purchase is awaiting approval. You'll get access as soon as it's confirmed."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed. You have not been charged — please try again."
        }
    }

    /// Marks the app unlocked when a verified transaction matches one of our
    /// products. Trusts a cryptographically `.verified` purchase directly, so it
    /// never depends on entitlement-refresh timing.
    func recordVerifiedPurchase(productID: String) {
        if Self.productIds.contains(productID) {
            state = .active
        }
    }

    func restore() async {
        restoring = true
        lastError = nil
        defer { restoring = false }
        do {
            try await AppStore.sync()
        } catch {
            lastError = "Couldn't restore. Make sure you're signed in to your Apple Account, then try again."
            return
        }
        await refresh()
        if !isUnlocked {
            lastError = "No active subscription found to restore."
        }
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
