import SwiftUI
import SwiftData
import Charts

struct ProgressScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.date) private var entries: [WeightEntry]
    @Query(sort: \UserSettings.createdAt) private var settingsList: [UserSettings]
    @Query(sort: \DoseLog.date) private var doseLogs: [DoseLog]
    @State private var showEntrySheet = false
    @State private var showRecap = false
    @State private var editingEntry: WeightEntry?
    @State private var errorMessage: String?

    private var metric: Bool { settingsList.first?.usesMetric ?? false }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthCard
                    if entries.isEmpty {
                        baselineNudge
                    } else {
                        statsCard
                    }
                    chartCard
                    if !entries.isEmpty {
                        weighInsCard
                    }
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
            .sheet(item: $editingEntry, onDismiss: { editingEntry = nil }) { entry in
                WeightEntrySheet(metric: metric, entry: entry)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showRecap) {
                RecapView()
            }
            .alert("Couldn't delete weigh-in", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var sortedEntries: [WeightEntry] {
        entries.sorted { $0.date > $1.date }
    }

    private var weighInsCard: some View {
        Card {
            SectionHeader(title: "Weigh-ins")
            VStack(spacing: 0) {
                ForEach(sortedEntries) { entry in
                    HStack {
                        Button {
                            editingEntry = entry
                        } label: {
                            HStack {
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(UnitFormat.weightString(kilograms: entry.kilograms, metric: metric))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            deleteEntry(entry)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete weigh-in")
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func deleteEntry(_ entry: WeightEntry) {
        context.delete(entry)
        do {
            try context.save()
        } catch {
            // Restore the in-memory deletion so the @Query-backed list doesn't
            // diverge from disk (the row reappears rather than silently vanishing).
            context.rollback()
            errorMessage = "Your weigh-in couldn't be deleted. Please try again."
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

    private var baselineNudge: some View {
        Card {
            SectionHeader(title: "Start tracking your progress")
            Text("Add your starting weight so GLPill can show your trend, total change, and milestones.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showEntrySheet = true
            } label: {
                Label("Add starting weight", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(Theme.primary)
        }
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
        guard remaining > 0 else { return "Reached ✓" }
        let display = metric ? remaining : remaining / UnitFormat.kgPerLb
        return String(format: "%.1f %@", display, metric ? "kg" : "lb")
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(weightChartSummary)
            }
        }
    }

    private var weightChartSummary: String {
        guard let first = entries.first, let last = entries.last else {
            return "Weight trend"
        }
        let firstText = UnitFormat.weightString(kilograms: first.kilograms, metric: metric)
        let lastText = UnitFormat.weightString(kilograms: last.kilograms, metric: metric)
        return "Weight trend, \(firstText) to \(lastText) over \(entries.count) entries"
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
            weeks: weeks,
            isGain: (change ?? 0) > 0
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage
    }
}
