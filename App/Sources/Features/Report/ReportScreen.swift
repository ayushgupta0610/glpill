import SwiftUI
import SwiftData

struct ReportScreen: View {
    @Environment(SubscriptionStore.self) private var subscriptions
    @State private var showPaywall = false
    @Query private var medications: [Medication]
    @Query(sort: \DoseLog.date) private var doseLogs: [DoseLog]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query(sort: \SideEffectLog.date) private var sideEffects: [SideEffectLog]
    @Query private var settingsList: [UserSettings]

    private var calendar: Calendar { .current }

    /// Clamp the window to days since the user started, so a day-3 user
    /// sees honest adherence instead of "4% of 28 days".
    private var windowDays: Int {
        guard let start = settingsList.first?.startDate else { return 28 }
        let elapsed = (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: .now)).day ?? 0) + 1
        return min(28, max(1, elapsed))
    }

    /// Earliest day the plan could have data: the earlier of the user's start
    /// date and their first logged dose. Floors the report's adherence + gap.
    private var planStart: Date? {
        let starts = [settingsList.first?.startDate, doseLogs.first?.date].compactMap { $0 }
        return starts.min()
    }

    private var windowStart: Date {
        calendar.date(byAdding: .day, value: -(windowDays - 1), to: calendar.startOfDay(for: .now))!
    }

    private var adherencePercent: Int {
        StreakCalculator.adherencePercent(doseDays: doseLogs.map(\.date), from: windowStart, to: .now, calendar: calendar)
    }

    private var sideEffectCount: Int {
        sideEffects.filter { $0.date >= windowStart }.count
    }

    private var weightChangeText: String {
        let metric = settingsList.first?.usesMetric ?? false
        let inWindow = weights.filter { $0.date >= windowStart }.map { (date: $0.date, kg: $0.kilograms) }
        guard let change = WeightStats.totalChange(entries: inWindow) else { return "—" }
        let display = metric ? change : change / UnitFormat.kgPerLb
        return String(format: "%+.1f %@", display, metric ? "kg" : "lb")
    }

    private var reportText: String {
        ReportComposer.compose(
            ReportInput(
                medName: medications.first?.displayName ?? "GLP-1 pill",
                windowDays: windowDays,
                doseDays: doseLogs.map(\.date),
                doses: doseLogs.map { ($0.date, $0.doseMg) },
                weights: weights.map { ($0.date, $0.kilograms) },
                sideEffects: sideEffects.map { ($0.date, $0.kind.label, $0.severity) },
                metric: settingsList.first?.usesMetric ?? false,
                today: .now,
                planStart: planStart
            ),
            calendar: calendar
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(windowDays < 28
                         ? "A summary since you started (\(windowDays) \(windowDays == 1 ? "day" : "days")) to bring to your next appointment."
                         : "A 4-week summary to bring to your next appointment.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Card {
                        HStack {
                            StatBadge(value: "\(adherencePercent)%", label: "Adherence")
                            StatBadge(value: weightChangeText, label: "Weight change", tint: .orange)
                            StatBadge(value: "\(sideEffectCount)", label: "Side effects", tint: Theme.warn)
                        }
                    }

                    if PremiumGate.shouldShowUpgrade(for: subscriptions.state) {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 8) {
                                Text("Export report")
                                Image(systemName: "lock.fill").font(.footnote)
                                Text("Premium")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.white.opacity(0.2), in: Capsule())
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primary)
                    } else {
                        ShareLink(item: reportText) {
                            HStack(spacing: 8) {
                                Text("Share with your doctor")
                                Image(systemName: "square.and.arrow.up")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primary)
                    }

                    Card {
                        SectionHeader(title: "Full report")
                        Text(reportText)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Doctor report")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}
