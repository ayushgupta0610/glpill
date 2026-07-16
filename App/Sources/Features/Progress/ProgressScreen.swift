import SwiftUI
import SwiftData
import Charts

struct ProgressScreen: View {
    @Query(sort: \WeightEntry.date) private var entries: [WeightEntry]
    @Query private var settingsList: [UserSettings]
    @Query(sort: \DoseLog.date) private var doseLogs: [DoseLog]
    @State private var showEntrySheet = false
    @State private var showRecap = false

    private var metric: Bool { settingsList.first?.usesMetric ?? false }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthCard
                    statsCard
                    chartCard
                    shareCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showEntrySheet = true
                    } label: {
                        Label("Add weight", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEntrySheet) {
                WeightEntrySheet(metric: metric)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showRecap) {
                RecapView()
            }
        }
    }

    private var monthCard: some View {
        Button {
            showRecap = true
        } label: {
            HStack(spacing: 14) {
                Text("✨").font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text("My Month")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("A shareable recap of your consistency")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.8))
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }

    private var statsCard: some View {
        Card {
            HStack {
                StatBadge(
                    value: entries.last.map { UnitFormat.weightString(kilograms: $0.kilograms, metric: metric) } ?? "—",
                    label: "Current"
                )
                StatBadge(value: changeString, label: "Total change", tint: .orange)
                StatBadge(value: toGoalString, label: "To goal", tint: .blue)
            }
        }
    }

    private var changeString: String {
        guard let change = WeightStats.totalChange(entries: entries.map { (date: $0.date, kg: $0.kilograms) }) else {
            return "—"
        }
        let display = metric ? change : change / UnitFormat.kgPerLb
        return String(format: "%+.1f %@", display, metric ? "kg" : "lb")
    }

    private var toGoalString: String {
        guard let current = entries.last?.kilograms, let goal = settingsList.first?.goalKilograms else { return "—" }
        let remaining = WeightStats.toGoal(current: current, goal: goal)
        let display = metric ? remaining : remaining / UnitFormat.kgPerLb
        return String(format: "%.1f %@", max(0, display), metric ? "kg" : "lb")
    }

    private var chartCard: some View {
        Card {
            SectionHeader(title: "Weight trend")
            if entries.count < 2 {
                VStack(spacing: 12) {
                    Text("Log at least two weigh-ins to see your curve.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        showEntrySheet = true
                    } label: {
                        Label("Add today's weight", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.primary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(entries) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", displayValue(entry.kilograms))
                    )
                    .foregroundStyle(Theme.primary)
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", displayValue(entry.kilograms))
                    )
                    .foregroundStyle(Theme.primary.opacity(0.12))
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: yDomain)
                .frame(height: 220)
            }
        }
    }

    private func displayValue(_ kilograms: Double) -> Double {
        metric ? kilograms : kilograms / UnitFormat.kgPerLb
    }

    private var yDomain: ClosedRange<Double> {
        let values = entries.map { displayValue($0.kilograms) }
        guard let min = values.min(), let max = values.max() else { return 0...1 }
        let padding = Swift.max((max - min) * 0.2, 2)
        return (min - padding)...(max + padding)
    }

    private var shareCard: some View {
        Card {
            SectionHeader(title: "Share your progress")
            Text("A clean card for your GLP-1 journey posts — no medication name on it.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let image = renderShareImage() {
                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview("My GLPill progress", image: Image(uiImage: image))
                ) {
                    Label("Share progress card", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    @MainActor
    private func renderShareImage() -> UIImage? {
        let change = WeightStats.totalChange(entries: entries.map { (date: $0.date, kg: $0.kilograms) })
        let weeks = settingsList.first.map {
            max(1, (Calendar.current.dateComponents([.day], from: $0.startDate, to: .now).day ?? 0) / 7)
        } ?? 1
        let card = ShareCardView(
            streak: StreakCalculator.currentStreak(doseDays: doseLogs.map(\.date), today: .now, calendar: .current),
            changeText: change.map {
                String(format: "%+.1f %@", metric ? $0 : $0 / UnitFormat.kgPerLb, metric ? "kg" : "lb")
            } ?? "Just started",
            weeks: weeks
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage
    }
}
