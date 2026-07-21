import SwiftUI
import Charts

struct MedLevelPreviewCard: View {
    let points: [MedicationLevel.Point]
    var body: some View {
        NavigationLink { MedicationLevelView(points: points) } label: {
            Card {
                HStack {
                    SectionHeader(title: "Medication level")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
                if points.isEmpty {
                    Text("Log doses to see your steady-state build")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Chart(points, id: \.date) { p in
                        LineMark(x: .value("Day", p.date), y: .value("Level", p.level))
                            .foregroundStyle(Theme.primary)
                    }
                    .chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 48)
                    Text("Steady daily levels — no peak-and-crash")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
