import SwiftUI

struct ActivityFeedView: View {
    let events: [ActivityEvent]
    let metric: Bool

    var body: some View {
        Card {
            SectionHeader(title: "Activity")
            if events.isEmpty {
                Text("No activity yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let shown = Array(events.prefix(10))
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, event in
                        row(for: event)
                        if index != shown.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func row(for event: ActivityEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: event.kind))
                .foregroundStyle(Theme.primary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: event.kind))
                    .font(.subheadline.weight(.medium))
                Text(event.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func icon(for kind: ActivityEvent.Kind) -> String {
        switch kind {
        case .weighIn: "scalemass"
        case .dose: "pills.fill"
        case .milestone: "flag.fill"
        }
    }

    private func title(for kind: ActivityEvent.Kind) -> String {
        switch kind {
        case .weighIn(let kg):
            "Logged \(UnitFormat.weightString(kilograms: kg, metric: metric))"
        case .dose:
            "Dose logged"
        case .milestone(let milestone):
            "Milestone reached: \(milestone.label)"
        }
    }
}
