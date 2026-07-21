import SwiftUI
import Charts

struct MedicationLevelView: View {
    let points: [MedicationLevel.Point]
    var projection: [MedicationLevel.Point] = []

    private var hasEnoughData: Bool { MedicationLevel.hasEnoughData(points: points) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimated medication level").font(.headline)
            Text("Steady daily levels — no peak-and-crash. Estimated, not a medical reading.")
                .font(.caption).foregroundStyle(.secondary)
            if hasEnoughData {
                Chart(points, id: \.date) { p in
                    AreaMark(x: .value("Day", p.date), y: .value("Level", p.level))
                        .foregroundStyle(Theme.primary.opacity(0.25))
                    LineMark(x: .value("Day", p.date), y: .value("Level", p.level))
                        .foregroundStyle(Theme.primary)
                }
                .frame(height: 220)
            } else {
                buildingState
            }
        }
        .padding()
    }

    private var buildingState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your level is building").font(.title3.bold())
            Text("Estimated to reach steady state in about a week — keep logging.")
                .font(.subheadline).foregroundStyle(.secondary)
            if !projection.isEmpty {
                Chart(projection, id: \.date) { p in
                    LineMark(x: .value("Day", p.date), y: .value("Level", p.level))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundStyle(Theme.primary.opacity(0.6))
                }
                .frame(height: 220)
            }
        }
    }
}
