import SwiftUI

struct JourneyTimelineView: View {
    let startDate: Date
    let milestones: [JourneyMilestone]
    let projectedCompletion: Date?
    let metric: Bool

    @State private var selectedMilestone: JourneyMilestone?

    var body: some View {
        Card {
            SectionHeader(title: "Timeline")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    chip(title: "Start", date: startDate, isDone: true)
                    ForEach(milestones) { milestone in
                        Button {
                            selectedMilestone = milestone
                        } label: {
                            chip(title: milestone.label, date: milestone.reachedDate, isDone: milestone.isReached)
                        }
                        .buttonStyle(.plain)
                    }
                    if let projectedCompletion {
                        chip(title: "Goal", date: projectedCompletion, isDone: false, isProjected: true)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .sheet(item: $selectedMilestone) { milestone in
            milestoneDetail(milestone)
        }
    }

    private func chip(title: String, date: Date?, isDone: Bool, isProjected: Bool = false) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(isDone ? Theme.primary : Color(.systemGray5))
                .frame(width: 12, height: 12)
                .overlay {
                    if isProjected {
                        Circle().strokeBorder(Theme.primary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    }
                }
            Text(title)
                .font(.caption.weight(.semibold))
            Text(date.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "—")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 64)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func milestoneDetail(_ milestone: JourneyMilestone) -> some View {
        VStack(spacing: 12) {
            Text(milestone.label)
                .font(.title2.bold())
            Text(UnitFormat.weightString(kilograms: milestone.targetKg, metric: metric))
                .font(.headline)
            if let reachedDate = milestone.reachedDate {
                Text("Reached \(reachedDate.formatted(date: .abbreviated, time: .omitted))")
                    .foregroundStyle(.secondary)
            } else {
                Text("Not reached yet")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .presentationDetents([.fraction(0.3)])
    }
}
