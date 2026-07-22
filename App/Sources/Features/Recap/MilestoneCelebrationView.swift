import SwiftUI
import SwiftData

/// Full-screen celebration shown once when a streak crosses a milestone.
/// Presents an animated count-up + tiered trophy + confetti burst (in-app only),
/// plus the shareable Trophy Card and a one-tap "share this win".
/// The EXPORTED image renders `TrophyCardView` alone — static, no motion/confetti.
struct MilestoneCelebrationView: View {
    let milestone: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \UserSettings.createdAt) private var settingsList: [UserSettings]
    @State private var appeared = false
    @State private var displayedCount = 0
    @State private var statsShown = false
    @State private var celebrateHaptic = false

    private var name: String? { settingsList.first?.firstName }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            animatedReveal

            TrophyCardView(milestone: milestone, name: name)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

            if let image = shareImage() {
                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview("\(milestone)-day streak on GLPill", image: Image(uiImage: image))
                ) {
                    Label("Share this win", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Theme.primary, in: Capsule())
                        .foregroundStyle(.white)
                }
                .opacity(statsShown ? 1 : 0)
                .offset(y: statsShown ? 0 : 12)
            }

            Button("Keep going") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .opacity(statsShown ? 1 : 0)
                .offset(y: statsShown ? 0 : 12)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .overlay {
            if !reduceMotion {
                ConfettiView(
                    count: MilestoneTier.particleCount(for: milestone),
                    colors: [Theme.primary, Theme.mint, MilestoneTier.ringColor(for: milestone), .white]
                )
            }
        }
        .sensoryFeedback(.success, trigger: celebrateHaptic)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
            }
            celebrateHaptic.toggle()
        }
        .task { await runCountUp() }
    }

    /// The animated headline shown above the static Trophy Card: tiered emoji with
    /// a ring, and the streak number counting up via numeric content transition.
    private var animatedReveal: some View {
        VStack(spacing: 12) {
            Text(MilestoneTier.emoji(for: milestone))
                .font(.system(size: 56))
                .padding(16)
                .overlay(
                    Circle().stroke(MilestoneTier.ringColor(for: milestone), lineWidth: 4)
                )
                .scaleEffect(appeared ? 1 : 0.6)

            Text("\(displayedCount)")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.primary)
                .contentTransition(.numericText())
                .monospacedDigit()

            Text(milestone == 1 ? "day" : "days")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .opacity(statsShown ? 1 : 0)
                .offset(y: statsShown ? 0 : 8)
        }
    }

    /// Counts the number up to the milestone with a numeric content transition,
    /// then staggers in the surrounding stat lines.
    private func runCountUp() async {
        guard !reduceMotion else {
            displayedCount = milestone
            statsShown = true
            return
        }
        let start = max(0, milestone - 10)
        displayedCount = start
        for value in stride(from: start, through: milestone, by: 1) {
            withAnimation(.snappy) { displayedCount = value }
            try? await Task.sleep(for: .milliseconds(70))
        }
        withAnimation(.easeOut(duration: 0.4)) { statsShown = true }
    }

    @MainActor
    private func shareImage() -> UIImage? {
        let renderer = ImageRenderer(content: TrophyCardView(milestone: milestone, name: name))
        renderer.scale = 3
        return renderer.uiImage
    }
}
