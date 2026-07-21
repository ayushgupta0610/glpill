import SwiftUI

/// A tappable selection row used across onboarding steps.
struct OnboardingOptionRow: View {
    let title: String
    let subtitle: String?
    let selected: Bool
    let multi: Bool
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                Image(systemName: iconName)
                    .foregroundStyle(selected ? Theme.primary : Color.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .stroke(selected ? Theme.primary : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
    private var iconName: String {
        if multi { return selected ? "checkmark.square.fill" : "square" }
        return selected ? "checkmark.circle.fill" : "circle"
    }
}
