import SwiftUI
import SwiftData
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionStore.self) private var subscriptions
    @Query private var medications: [Medication]
    @State private var selectedId = SubscriptionStore.yearlyId
    @State private var purchasing = false
    @State private var showPrivacy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                hero
                featureList
                planPicker
                ctaSection
                footerLinks
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showPrivacy) {
            NavigationStack { PrivacyPolicyView() }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            Image(systemName: "pills.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 22))
                .shadow(color: Theme.primary.opacity(0.35), radius: 14, y: 6)
            Text(heroTitle)
                .font(.system(.largeTitle, design: .rounded).bold())
                .multilineTextAlignment(.center)
            Text("Stay consistent, watch the scale move, and walk into every appointment prepared.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 28)
    }

    private var heroTitle: String {
        if let med = medications.first {
            let shortName = med.displayName.components(separatedBy: " (").first ?? med.displayName
            return "Your \(shortName) plan is ready"
        }
        return "Make every pill count"
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            feature("pills.fill", "Never miss a dose", "One-tap logging, streaks and a daily reminder")
            feature("clock.fill", "Rybelsus® timer", "30-minute empty-stomach countdown, automatic")
            feature("chart.line.uptrend.xyaxis", "Watch it work", "Weight trend, milestones and share-ready cards")
            feature("doc.text.fill", "Doctor-ready reports", "Adherence, doses and side effects in one summary")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    private func feature(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 40, height: 40)
                .background(Theme.primary.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var planPicker: some View {
        if subscriptions.products.isEmpty {
            VStack(spacing: 12) {
                if subscriptions.lastError != nil {
                    Text("Couldn't reach the App Store.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Try again") {
                        Task { await subscriptions.loadProducts() }
                    }
                    .buttonStyle(.bordered)
                } else {
                    ProgressView()
                        .padding(.vertical, 12)
                    Text("Loading plans…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        } else {
            VStack(spacing: 10) {
                ForEach(subscriptions.products.sorted { $0.price > $1.price }, id: \.id) { product in
                    planCard(product)
                }
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isYearly = product.id == SubscriptionStore.yearlyId
        let selected = selectedId == product.id
        return Button {
            selectedId = product.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(isYearly ? "Yearly" : "Monthly")
                            .font(.headline)
                        if isYearly {
                            Text(trialBadge(product))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.warn, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(planSubtitle(product, isYearly: isYearly))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.primary : Color.secondary.opacity(0.4))
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .stroke(selected ? Theme.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func trialBadge(_ product: Product) -> String {
        if let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
            return "\(offer.period.value)-DAY FREE TRIAL"
        }
        return "BEST VALUE"
    }

    private func planSubtitle(_ product: Product, isYearly: Bool) -> String {
        if isYearly {
            let weekly = product.price / 52
            let weeklyString = weekly.formatted(product.priceFormatStyle)
            if let savings = yearlySavingsPercent {
                return "\(product.displayPrice)/year — \(weeklyString)/week · Save \(savings)%"
            }
            return "\(product.displayPrice)/year — just \(weeklyString) a week"
        }
        return "\(product.displayPrice)/month, flexible"
    }

    private var yearlySavingsPercent: Int? {
        guard let yearly = subscriptions.products.first(where: { $0.id == SubscriptionStore.yearlyId }),
              let monthly = subscriptions.products.first(where: { $0.id == SubscriptionStore.monthlyId }) else {
            return nil
        }
        let fullYear = monthly.price * 12
        guard fullYear > 0 else { return nil }
        let ratio = (fullYear - yearly.price) / fullYear * 100
        let percent = Int(NSDecimalNumber(decimal: ratio).doubleValue.rounded())
        return percent > 0 ? percent : nil
    }

    private var ctaSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                reassurance("iphone.gen3", "Data stays on iPhone")
                reassurance("person.crop.circle.badge.xmark", "No account needed")
                reassurance("apple.logo", "Billed by Apple")
            }
            .padding(.bottom, 2)

            Button {
                purchase()
            } label: {
                HStack {
                    if purchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(ctaTitle)
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
            .disabled(purchasing || subscriptions.products.isEmpty)

            Text(ctaSubtext)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error = subscriptions.lastError, !subscriptions.products.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var selectedProduct: Product? {
        subscriptions.products.first { $0.id == selectedId }
    }

    private var ctaTitle: String {
        guard let product = selectedProduct else { return "Continue" }
        if product.id == SubscriptionStore.yearlyId,
           let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
            return "Start my free trial"
        }
        return "Continue — \(product.displayPrice)/mo"
    }

    private var ctaSubtext: String {
        guard let product = selectedProduct else { return "" }
        if product.id == SubscriptionStore.yearlyId,
           let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
            return "No payment now. \(offer.period.value) days free, then \(product.displayPrice)/year. Cancel anytime."
        }
        return "Billed monthly. Cancel anytime."
    }

    private func reassurance(_ icon: String, _ text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(Theme.primary)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func purchase() {
        guard let product = selectedProduct else { return }
        purchasing = true
        Task {
            await subscriptions.purchase(product)
            purchasing = false
        }
    }

    private var footerLinks: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                Button("Restore Purchases") {
                    Task { await subscriptions.restore() }
                }
                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Button("Privacy") { showPrivacy = true }
            }
            .font(.caption.weight(.medium))

            Text("Auto-renews until cancelled in Settings › Apple Account › Subscriptions. Tracking tool — not medical advice. All data stays on your iPhone.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
}
