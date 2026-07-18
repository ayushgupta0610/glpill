#if DEBUG
import SwiftUI
import UIKit

/// DEBUG-only: renders a faithful still of the paywall (with the 7-day trial) to a
/// PNG, for the App Store Connect subscription "Review Information" screenshot and
/// marketing. Triggered by the `-exportPaywall` launch argument. Uses static copy
/// so it renders without a live StoreKit session.
@MainActor
enum PaywallShotExporter {
    static func export() {
        let renderer = ImageRenderer(content: PaywallReviewView().frame(width: 430, height: 932))
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else { return }
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("paywall-review.png")
        try? data.write(to: url)
    }
}

private struct PaywallReviewView: View {
    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 20))
                Text("Make every pill count")
                    .font(.system(.title, design: .rounded).bold())
                    .multilineTextAlignment(.center)
                Text("Stay consistent, watch the scale move, and never lose your history — it syncs privately across your devices.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.top, 22)

            VStack(alignment: .leading, spacing: 12) {
                feature("pills.fill", "Never miss a dose", "One-tap logging, streaks and a daily reminder")
                feature("clock.fill", "Rybelsus® timer", "30-minute empty-stomach countdown, automatic")
                feature("icloud.fill", "Never lose your history", "Syncs privately across your devices")
                feature("chart.line.uptrend.xyaxis", "Watch it work", "Weight trend, milestones and share-ready cards")
                feature("doc.text.fill", "Doctor-ready reports", "Adherence, doses and side effects in one summary")
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 10) {
                planCard(title: "Yearly", subtitle: "$39.99/year — just $0.77 a week · Save 52%", badge: "7-DAY FREE TRIAL", selected: true)
                planCard(title: "Monthly", subtitle: "$6.99/month, flexible", badge: nil, selected: false)
            }

            VStack(spacing: 8) {
                Text("Start my 7-day free trial")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 14))
                Text("No payment now. 7 days free, then $39.99/year. Cancel anytime.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(width: 430, height: 932)
        .background(Color(.systemGroupedBackground))
    }

    private func feature(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 36, height: 36)
                .background(Theme.primary.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func planCard(title: String, subtitle: String, badge: String?, selected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title).font(.headline)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.warn, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected ? Theme.primary : Color.secondary.opacity(0.4))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Theme.primary : .clear, lineWidth: 2))
    }
}
#endif
