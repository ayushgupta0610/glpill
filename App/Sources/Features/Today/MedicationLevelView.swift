import SwiftUI
import Charts

struct MedicationLevelView: View {
    let points: [MedicationLevel.Point]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimated medication level").font(.headline)
            Text("Steady daily levels — no peak-and-crash. Estimated, not a medical reading.")
                .font(.caption).foregroundStyle(.secondary)
            if points.isEmpty {
                ContentUnavailableView("Log a few doses to see your level build", systemImage: "chart.line.uptrend.xyaxis")
            } else {
                Chart(points, id: \.date) { p in
                    AreaMark(x: .value("Day", p.date), y: .value("Level", p.level))
                        .foregroundStyle(Theme.primary.opacity(0.25))
                    LineMark(x: .value("Day", p.date), y: .value("Level", p.level))
                        .foregroundStyle(Theme.primary)
                }
                .frame(height: 220)
            }
        }
        .padding()
    }
}
