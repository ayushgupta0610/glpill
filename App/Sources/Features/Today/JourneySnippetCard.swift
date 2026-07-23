import SwiftUI

struct JourneySnippetCard: View {
    @Environment(AppRouter.self) private var router
    let daysSinceStart: Int
    let percentToGoal: Int
    let paceText: String
    let paceIsWarning: Bool

    var body: some View {
        Button {
            router.selection = .progress
        } label: {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day \(daysSinceStart) · \(percentToGoal)% to goal")
                            .font(.subheadline.weight(.semibold))
                        Text(paceText)
                            .font(.caption)
                            .foregroundStyle(paceIsWarning ? Theme.warn : .secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
