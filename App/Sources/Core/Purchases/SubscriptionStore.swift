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
    private let refreshTimeout: Duration
    private let syncAppStore: @Sendable () async throws -> Void
    private(set) var state: EntitlementState = .unknown
    private(set) var products: [Product] = []
    private(set) var productsLoaded = false
    private(set) var restoring = false
    var lastError: String?
    private var listenerTask: Task<Void, Never>?

    var isUnlocked: Bool { state == .active }

    init(
        provider: EntitlementProviding = StoreKitEntitlementProvider(),
        refreshTimeout: Duration = .seconds(5),
        syncAppStore: @escaping @Sendable () async throws -> Void = { try await AppStore.sync() }
    ) {
        self.provider = provider
        self.refreshTimeout = refreshTimeout
        self.syncAppStore = syncAppStore
    }

    /// Resolves entitlement state, racing the provider against `refreshTimeout`.
    /// If the provider hasn't answered in time and state is still `.unknown`,
    /// fails CLOSED to `.locked` so the user always reaches the paywall instead
    /// of being stuck on the loading splash forever (never fail open).
    ///
    /// `refresh()` itself only ever awaits one thing: a single `CheckedContinuation`
    /// that is resumed EXACTLY ONCE by whichever of two fully independent,
    /// unstructured background tasks finishes first — a provider task or a sleep
    /// task. This deliberately avoids `TaskGroup`/`withTaskGroup`: a task group
    /// implicitly awaits every child (including the race's loser) before it can
    /// return, so if the real provider (`Transaction.currentEntitlements`) hangs
    /// and ignores cancellation, that implicit teardown await would hang too and
    /// `refresh()` would never return. Here, if the provider hangs, the sleep task
    /// resumes the continuation on its own — `refresh()` never waits on the
    /// provider task at all, so the timeout wins definitively regardless of what
    /// the provider does afterwards. The provider task is left running in the
    /// background in that case; its late result is applied only if `state` is
    /// still `.unknown` when it lands, i.e. only if the timeout hasn't already
    /// committed a fail-closed value.
    func refresh() async {
        let previous = state
        let providerTask = Task.detached { [provider] in
            await provider.currentState()
        }

        let resumed = ResumeOnce<EntitlementState?>()

        // Forwards the provider's result the moment it arrives — but only takes
        // effect if the sleep task below hasn't already resumed first.
        Task { [weak self] in
            let result = await providerTask.value
            await resumed.resume(with: result)
            await self?.recordLateProviderResult(result)
        }

        // Independent timer: resumes with `nil` ("timed out") if the provider
        // hasn't answered first. This task never awaits the provider, so it is
        // guaranteed to fire on schedule even if the provider is hung.
        Task {
            try? await Task.sleep(for: refreshTimeout)
            await resumed.resume(with: nil)
        }

        let raceResult = await resumed.wait()

        if let raceResult {
            state = raceResult
        } else if state == .unknown {
            // Timeout fired first with no provider answer yet.
            providerTask.cancel()
            state = previous == .unknown ? .locked : previous
        }

        // A live downgrade (refund / expiry / lapse) arrives via the transaction
        // listener. Explain it so being sent to the paywall doesn't look like the
        // app reset or lost data.
        if previous == .active && state != .active {
            lastError = "Your subscription has ended. Renew to keep using GLPill."
        }
    }

    /// Applies a provider result that arrived after `refresh()` already returned
    /// (a late/background resolution). Only takes effect while `state` is still
    /// `.unknown` — once the timeout (or a normal fast resolution) has committed
    /// a value, a late result must never overwrite it.
    private func recordLateProviderResult(_ result: EntitlementState) {
        guard state == .unknown else { return }
        state = result
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.productIds)
                .sorted { $0.price < $1.price }
            lastError = nil
        } catch {
            lastError = "Could not load subscription options. Check your connection and try again."
        }
        // Set even when the fetch succeeds but returns nothing (products not yet
        // available on the App Store) so the paywall can stop showing an infinite
        // spinner and offer a retry instead of trapping the user.
        productsLoaded = true
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
            try await syncAppStore()
        } catch {
            lastError = "Couldn't restore. Make sure you're signed in to your Apple Account, then try again."
            return
        }
        // Check entitlements DIRECTLY (no 5s timeout race). A real subscriber on
        // a cold connection would be wrongly told "none found" if we relied on
        // refresh()'s fail-closed timeout, so only report "none" when the direct
        // check definitively finds nothing.
        switch await provider.directCheck() {
        case .active:
            state = .active
        case .none:
            state = .locked
            lastError = "No active subscription found to restore."
        case .inconclusive:
            lastError = "Couldn't confirm your subscription — check your connection and try again."
        }
    }

    /// Starts the long-lived listener for transaction updates (renewals, refunds,
    /// Ask to Buy). Idempotent: only starts if not already running, and the task
    /// is retained on the store so its lifetime is tied to the store rather than
    /// to a transient view `.task`.
    func startTransactionListener() {
        guard listenerTask == nil else { return }
        listenerTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
    }
}

/// A one-shot resumable value, resumed by whichever of two independent racing
/// tasks calls `resume(with:)` first — later calls are silently dropped. Used
/// by `SubscriptionStore.refresh()` so the awaiting caller (`wait()`) is never
/// itself awaiting the potentially-hung provider task; it only awaits this
/// actor's continuation, which the timer task can resume on schedule
/// regardless of what the provider task does.
private actor ResumeOnce<Value: Sendable> {
    private enum State {
        case waiting(CheckedContinuation<Value, Never>)
        case resumed
        case notAwaitedYet
    }

    private var state: State = .notAwaitedYet
    private var pendingValue: Value?

    func resume(with value: Value) {
        switch state {
        case .waiting(let continuation):
            state = .resumed
            continuation.resume(returning: value)
        case .notAwaitedYet:
            // wait() hasn't been called yet — stash the value so it's delivered
            // immediately once it is.
            state = .resumed
            pendingValue = value
        case .resumed:
            break
        }
    }

    func wait() async -> Value {
        if case .resumed = state, let pendingValue {
            return pendingValue
        }
        return await withCheckedContinuation { continuation in
            state = .waiting(continuation)
        }
    }
}
