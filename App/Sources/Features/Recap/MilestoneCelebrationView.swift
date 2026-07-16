import SwiftUI

/// Full-screen celebration shown once when a streak crosses a milestone.
/// Presents the shareable Trophy Card and a one-tap "share this win".
struct MilestoneCelebrationView: View {
    let milestone: Int
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            TrophyCardView(milestone: milestone)
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
            }

            Button("Keep going") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }

    @MainActor
    private func shareImage() -> UIImage? {
        let renderer = ImageRenderer(content: TrophyCardView(milestone: milestone))
        renderer.scale = 3
        return renderer.uiImage
    }
}
