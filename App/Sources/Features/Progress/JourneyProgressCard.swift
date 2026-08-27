import SwiftUI

struct JourneyProgressCard: View {
    /// 0...1, nil when no goal weight is set (ring track renders empty).
    let percentToGoal: Double?
    let currentWeightText: String
    let sinceLastWeekText: String
    let sinceStartText: String
    let velocityText: String
    let projectedCompletionText: String
    let streak: Int

    var body: some View {
        Card {
            SectionHeader(title: "Progress")
            HStack(spacing: 20) {
                ring
                VStack(alignment: .leading, spacing: 6) {
                    Text(sinceLastWeekText)
                        .font(.caption.weight(.medium))
                    Text(sinceStartText)
                        .font(.caption.weight(.medium))
                    Text(velocityText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(projectedCompletionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            if streak > 0 {
                Divider()
                Label("\(streak)-day streak", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 12)
            if let percentToGoal {
                Circle()
                    .trim(from: 0, to: max(0, min(1, percentToGoal)))
                    .stroke(Theme.heroGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: percentToGoal)
            }
            VStack(spacing: 2) {
                Text(currentWeightText)
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let percentToGoal {
                    Text("\(Int((percentToGoal * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 110, height: 110)
    }
}
