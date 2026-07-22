import SwiftUI
import Charts

struct MedicationLevelView: View {
    let points: [MedicationLevel.Point]
    var projection: [MedicationLevel.Point] = []
    var kind: MedicationKind = .custom
    var firstDose: Date?

    private var hasEnoughData: Bool { MedicationLevel.hasEnoughData(points: points) }

    /// Only once elapsed ≥ 3 half-lives do we call the level "steady"; before that
    /// it's still visibly climbing and mustn't be labelled a plateau.
    private var isNearSteadyState: Bool {
        guard let firstDose else { return false }
        return MedicationLevel.isNearSteadyState(
            firstDose: firstDose, now: .now,
            halfLifeHours: MedicationLevel.halfLifeHours(for: kind)
        )
    }

    private var caption: String {
        isNearSteadyState
            ? "Steady daily levels — no peak-and-crash. Estimated, not a medical reading."
            : "Still climbing toward steady state — estimated, not a medical reading."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimated medication level").font(.headline)
            if hasEnoughData {
                Text(caption)
                    .font(.caption).foregroundStyle(.secondary)
                Chart(points, id: \.date) { p in
                    AreaMark(x: .value("Day", p.date), y: .value("Level", p.level))
                        .foregroundStyle(Theme.primary.opacity(0.25))
                    LineMark(x: .value("Day", p.date), y: .value("Level", p.level))
                        .foregroundStyle(Theme.primary)
                }
                .chartYAxis(.hidden)
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Estimated medication level, \(isNearSteadyState ? "steady daily levels" : "still climbing toward steady state").")
            } else {
                buildingState
            }
        }
        .padding()
    }

    private var buildingState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your level is building").font(.title3.bold())
            Text("Estimated to reach steady state in \(MedicationLevel.timeToSteadyStateText(for: kind)) — keep logging.")
                .font(.subheadline).foregroundStyle(.secondary)
            if !projection.isEmpty {
                Chart(projection, id: \.date) { p in
                    LineMark(x: .value("Day", p.date), y: .value("Level", p.level))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundStyle(Theme.primary.opacity(0.6))
                }
                .chartYAxis(.hidden)
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Estimated medication level, building toward steady state.")
            }
        }
    }
}
