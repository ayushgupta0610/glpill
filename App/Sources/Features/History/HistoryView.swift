import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \DoseLog.date) private var doseLogs: [DoseLog]
    @Query(sort: \SideEffectLog.date) private var sideEffects: [SideEffectLog]
    @State private var monthAnchor = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay: Date?

    private var calendar: Calendar { .current }

    private var dosedDays: Set<Date> {
        Set(doseLogs.map { calendar.startOfDay(for: $0.date) })
    }

    private var effectDays: Set<Date> {
        Set(sideEffects.map { calendar.startOfDay(for: $0.date) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthHeader
                    Card {
                        monthGrid
                        HStack(spacing: 16) {
                            legend(color: Theme.primary, text: "Pill taken")
                            legend(color: Theme.warn, text: "Side effect")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("History")
            .sheet(item: $selectedDay) { day in
                DayDetailSheet(day: day)
                    .presentationDetents([.medium])
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                monthAnchor = calendar.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button {
                monthAnchor = calendar.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal, 4)
    }

    private var monthGrid: some View {
        let days = monthDays()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(["S", "M", "T", "W", "T", "F", "S"].indices, id: \.self) { index in
                Text(["S", "M", "T", "W", "T", "F", "S"][index])
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(days.indices, id: \.self) { index in
                if let day = days[index] {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 36)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let dosed = dosedDays.contains(day)
        let hasEffect = effectDays.contains(day)
        let isFuture = day > calendar.startOfDay(for: .now)

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(dosed ? .bold : .regular))
                    .foregroundStyle(dosed ? .white : (isFuture ? .secondary : .primary))
                    .frame(width: 32, height: 32)
                    .background(dosed ? Theme.primary : Color.clear, in: Circle())
                Circle()
                    .fill(hasEffect ? Theme.warn : Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(accessibilityText(for: day, dosed: dosed, hasEffect: hasEffect))
    }

    private func accessibilityText(for day: Date, dosed: Bool, hasEffect: Bool) -> String {
        var parts = [day.formatted(date: .long, time: .omitted)]
        parts.append(dosed ? "pill taken" : "no pill logged")
        if hasEffect { parts.append("side effect logged") }
        return parts.joined(separator: ", ")
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }

    /// Days of the anchored month padded with leading nils to align weekdays.
    private func monthDays() -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: monthAnchor),
              let dayCount = calendar.range(of: .day, in: .month, for: monthAnchor)?.count else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = Array<Date?>(repeating: nil, count: firstWeekday - 1)
        let days = (0..<dayCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: interval.start)
        }
        return leading + days.map { Optional($0) }
    }
}

extension Date: Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

private struct DayDetailSheet: View {
    let day: Date
    @Query private var doseLogs: [DoseLog]
    @Query private var sideEffects: [SideEffectLog]
    @Query private var intakeDays: [IntakeDay]
    @Query private var settingsList: [UserSettings]

    private var calendar: Calendar { .current }
    private var metric: Bool { settingsList.first?.usesMetric ?? false }

    var body: some View {
        NavigationStack {
            List {
                Section("Dose") {
                    let logs = doseLogs.filter { calendar.isDate($0.date, inSameDayAs: day) }
                    if logs.isEmpty {
                        Text("No pill logged")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(logs) { log in
                        Label(
                            String(format: "%g mg at %@", log.doseMg, log.takenAt.formatted(date: .omitted, time: .shortened)),
                            systemImage: "pills.fill"
                        )
                    }
                }
                Section("Side effects") {
                    let effects = sideEffects.filter { calendar.isDate($0.date, inSameDayAs: day) }
                    if effects.isEmpty {
                        Text("None logged")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(effects) { effect in
                        HStack {
                            Text("\(effect.kind.emoji) \(effect.kind.label)")
                            Spacer()
                            Text(severityLabel(effect.severity))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Intake") {
                    if let intake = intakeDays.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
                        LabeledContent("Protein", value: "\(intake.proteinGrams) g")
                        LabeledContent("Water", value: metric
                            ? "\(intake.waterMl) ml"
                            : "\(Int((Double(intake.waterMl) / 29.5735).rounded())) oz")
                    } else {
                        Text("Nothing tracked")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(day.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func severityLabel(_ severity: Int) -> String {
        switch severity {
        case 1: return "Mild"
        case 2: return "Moderate"
        default: return "Severe"
        }
    }
}
