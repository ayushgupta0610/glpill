import SwiftUI

/// Title + "Day N · X% to goal · <pace>" summary line for the Progress tab.
struct JourneyHeaderView: View {
    let daysSinceStart: Int
    let percentToGoal: Int?
    let paceText: String
    let paceIsWarning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Weight Loss Journey")
                .font(.largeTitle.bold())
            HStack(spacing: 6) {
                Text("Day \(daysSinceStart)")
                if let percentToGoal {
                    Text("· \(percentToGoal)% to goal")
                }
                Text("· \(paceText)")
                    .foregroundStyle(paceIsWarning ? Theme.warn : Theme.primary)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
