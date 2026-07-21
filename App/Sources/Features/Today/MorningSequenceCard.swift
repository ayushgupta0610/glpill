import SwiftUI

struct MorningSequenceCard: View {
    let steps: [MorningSequence.Step]
    var body: some View {
        Card {
            SectionHeader(title: "Your morning sequence")
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                HStack(spacing: 12) {
                    Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(step.done ? Theme.primary : Color.secondary.opacity(0.5))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.title).font(.subheadline.weight(.medium))
                        if let subtitle = step.subtitle {
                            Text(subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}
