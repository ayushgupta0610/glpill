import SwiftUI

struct WeightShortcutCard: View {
    /// Latest weight in kilograms, or nil if none logged yet.
    let latestKilograms: Double?
    let metric: Bool

    var body: some View {
        NavigationLink { ProgressScreen() } label: {
            Card {
                HStack {
                    SectionHeader(title: "Weight")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
                if let latestKilograms {
                    Text(UnitFormat.weightString(kilograms: latestKilograms, metric: metric))
                        .font(.title3.bold())
                    Text("See your trend")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Log your first weigh-in")
                        .font(.subheadline.weight(.medium))
                    Text("See your trend over time")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
