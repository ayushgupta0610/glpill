import SwiftUI

/// One-time, calm orientation card shown near the top of Today, tailored to the
/// user's onboarding stage. Timing/logging guidance only — no medical advice.
struct StageCoachingCard: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hand.wave.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.primary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Dismiss")
            }
        }
    }
}
