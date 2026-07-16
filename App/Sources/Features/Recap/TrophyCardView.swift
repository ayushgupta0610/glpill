import SwiftUI

/// The shareable milestone card shown when a streak crosses 7 / 30 / 100 / 365 days.
/// Like the Wrapped card, it celebrates the streak only — no medication, no weight.
struct TrophyCardView: View {
    let milestone: Int
    var name: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "pills.fill")
                Text("GLPill").font(.headline.bold())
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.9))

            Spacer()

            if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                Text(name.uppercased())
                    .font(.subheadline.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 6)
            }

            Text("🏆").font(.system(size: 72))
            Text("\(milestone)")
                .font(.system(size: 96, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(milestone == 1 ? "day" : "days")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))

            Spacer(minLength: 18)

            Text(StreakMilestone.headline(for: milestone))
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)

            Spacer()

            Text("glpillapp.com")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(28)
        .frame(width: 360, height: 640)
        .background(Theme.heroGradient)
    }
}
