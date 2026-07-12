import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionStore.self) private var subscriptions

    var body: some View {
        SubscriptionStoreView(productIDs: [SubscriptionStore.yearlyId, SubscriptionStore.monthlyId]) {
            marketingContent
        }
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStoreControlStyle(.prominentPicker)
        .tint(Theme.primary)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success(let verification)) = result,
               case .verified(let transaction) = verification {
                await transaction.finish()
            }
            await subscriptions.refresh()
        }
        .safeAreaInset(edge: .bottom) {
            Text("Auto-renews until cancelled in Settings › Apple Account › Subscriptions. Tracking tool — not medical advice.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 4)
        }
    }

    private var marketingContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 22))
            Text("GLPill Pro")
                .font(.title.bold())
            Text("Everything you need to stay consistent on your GLP-1 pill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 8) {
                feature("pills.fill", "Daily tracking, streaks & smart reminders")
                feature("clock.fill", "Rybelsus® empty-stomach timer")
                feature("chart.line.uptrend.xyaxis", "Weight trend, milestones & share cards")
                feature("doc.text.fill", "Doctor-visit summary export")
            }
        }
        .padding(.horizontal)
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.primary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}
