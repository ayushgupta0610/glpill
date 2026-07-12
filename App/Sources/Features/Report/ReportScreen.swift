import SwiftUI
import SwiftData

struct ReportScreen: View {
    @Query private var medications: [Medication]
    @Query(sort: \DoseLog.date) private var doseLogs: [DoseLog]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query(sort: \SideEffectLog.date) private var sideEffects: [SideEffectLog]
    @Query private var settingsList: [UserSettings]

    private var reportText: String {
        ReportComposer.compose(
            ReportInput(
                medName: medications.first?.displayName ?? "GLP-1 pill",
                windowDays: 28,
                doseDays: doseLogs.map(\.date),
                doses: doseLogs.map { ($0.date, $0.doseMg) },
                weights: weights.map { ($0.date, $0.kilograms) },
                sideEffects: sideEffects.map { ($0.date, $0.kind.label, $0.severity) },
                metric: settingsList.first?.usesMetric ?? true,
                today: .now
            ),
            calendar: .current
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("A 4-week summary to bring to your next appointment.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Card {
                        Text(reportText)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Doctor report")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: reportText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
