import SwiftUI
import Charts

struct MedLevelPreviewCard: View {
    let points: [MedicationLevel.Point]
    var projection: [MedicationLevel.Point] = []
    var kind: MedicationKind = .custom
    var firstDose: Date?

    private var hasEnoughData: Bool { MedicationLevel.hasEnoughData(points: points) }

    private var isNearSteadyState: Bool {
        guard let firstDose else { return false }
        return MedicationLevel.isNearSteadyState(
            firstDose: firstDose, now: .now,
            halfLifeHours: MedicationLevel.halfLifeHours(for: kind)
        )
    }

    var body: some View {
        NavigationLink { MedicationLevelView(points: points, projection: projection, kind: kind, firstDose: firstDose) } label: {
            Card {
                HStack {
                    SectionHeader(title: "Medication level")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
                if hasEnoughData {
                    Chart(points, id: \.date) { p in
                        LineMark(x: .value("Day", p.date), y: .value("Level", p.level))
                            .foregroundStyle(Theme.primary)
                    }
                    .chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 48)
                    Text(isNearSteadyState ? "Steady daily levels — no peak-and-crash" : "Still climbing toward steady state")
                        .font(.caption2).foregroundStyle(.secondary)
                } else if !projection.isEmpty {
                    Chart {
                        RuleMark(y: .value("base", 0))
                            .foregroundStyle(.secondary.opacity(0.2))
                        ForEach(projection, id: \.date) { p in
                            LineMark(x: .value("Day", p.date), y: .value("Level", p.level))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundStyle(Theme.primary.opacity(0.6))
                        }
                    }
                    .chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 48)
                    Text("Building toward steady state — keep logging")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Log doses to see your steady-state build")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
