import SwiftUI
import SwiftData

/// Scoped `Identifiable` wrapper for the day selected in the calendar grid.
/// Deliberately not a global `Date: Identifiable` extension — that conformance
/// is an app-wide footgun (any `Date?` binding elsewhere would silently pick it up).
private struct HistoryDay: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

struct HistoryView: View {
    @Query(sort: \DoseLog.date) private var doseLogs: [DoseLog]
    @Query(sort: \SideEffectLog.date) private var sideEffects: [SideEffectLog]
    @Query(sort: \UserSettings.createdAt) private var settingsList: [UserSettings]
    @Query(sort: \WeightEntry.date) private var weightEntries: [WeightEntry]
    @State private var monthAnchor = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay: HistoryDay?

    private var calendar: Calendar { .current }

    private var dosedDays: Set<Date> {
        Set(doseLogs.map { calendar.startOfDay(for: $0.date) })
    }

    private var effectDays: Set<Date> {
        Set(sideEffects.map { calendar.startOfDay(for: $0.date) })
    }

    private var weighInDays: Set<Date> {
        Set(weightEntries.map { calendar.startOfDay(for: $0.date) })
    }

    private var milestoneDays: Set<Date> {
        guard let settings = settingsList.first,
              let goalKg = settings.goalKilograms,
              let startKg = settings.startKilograms ?? weightEntries.first?.kilograms else { return [] }
        let milestones = JourneyMilestones.generate(
            startKg: startKg,
            goalKg: goalKg,
            entries: weightEntries.map { (date: $0.date, kg: $0.kilograms) }
        )
        return Set(milestones.compactMap { $0.reachedDate.map { calendar.startOfDay(for: $0) } })
    }

    /// The first day a dose was "expected" — the earlier of the user's plan start
    /// or their first logged dose. Days before this read as blank, not missed.
    private var planStart: Date? {
        let settingsStart = settingsList.first.map { calendar.startOfDay(for: $0.startDate) }
        let firstDose = dosedDays.min()
        return [settingsStart, firstDose].compactMap { $0 }.min()
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
                            legend(color: Theme.mint, text: "Milestone")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("History")
            .sheet(item: $selectedDay, onDismiss: { selectedDay = nil }) { day in
                DayDetailSheet(day: day.date)
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
            ForEach(weekdayHeaderSymbols.indices, id: \.self) { index in
                Text(weekdayHeaderSymbols[index])
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(days.indices, id: \.self) { index in
                if let day = days[index] {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    /// Short weekday symbols rotated so column 0 is the locale's `firstWeekday`.
    private var weekdayHeaderSymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols // index 0 = Sunday
        let shift = calendar.firstWeekday - 1
        guard shift > 0 else { return symbols }
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private func dayCell(_ day: Date) -> some View {
        let dosed = dosedDays.contains(day)
        let hasEffect = effectDays.contains(day)
        let hasWeighIn = weighInDays.contains(day)
        let hasMilestone = milestoneDays.contains(day)
        let isFuture = day > calendar.startOfDay(for: .now)
        // A day is "missed" when it's expected (past-or-today, on/after the plan
        // start) but has no dose — a gap, distinct from a blank future day.
        let isMissed = !dosed && !isFuture && planStart.map { day >= $0 } == true

        return Button {
            selectedDay = HistoryDay(date: day)
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(dosed ? .bold : .regular))
                    .foregroundStyle(dosed ? .white : (isFuture ? .secondary : .primary))
                    .frame(width: 32, height: 32)
                    .background(dosed ? Theme.primary : Color.clear, in: Circle())
                    .overlay {
                        if isMissed {
                            Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                        }
                        if hasMilestone {
                            Circle().stroke(Theme.mint, lineWidth: 2)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if dosed {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(1)
                        }
                    }
                HStack(spacing: 3) {
                    Circle().fill(hasEffect ? Theme.warn : Color.clear).frame(width: 5, height: 5)
                    Circle().fill(hasWeighIn ? Theme.primary : Color.clear).frame(width: 5, height: 5)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(accessibilityText(for: day, dosed: dosed, hasEffect: hasEffect, missed: isMissed, hasWeighIn: hasWeighIn, hasMilestone: hasMilestone))
    }

    private func accessibilityText(for day: Date, dosed: Bool, hasEffect: Bool, missed: Bool, hasWeighIn: Bool, hasMilestone: Bool) -> String {
        var parts = [day.formatted(date: .long, time: .omitted)]
        if dosed {
            parts.append("pill taken")
        } else if missed {
            parts.append("missed")
        } else {
            parts.append("no pill logged")
        }
        if hasEffect { parts.append("side effect logged") }
        if hasWeighIn { parts.append("weigh-in logged") }
        if hasMilestone { parts.append("milestone reached") }
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
        let leadingCount = CalendarLayout.leadingBlanks(
            firstWeekdayOfMonth: firstWeekday,
            calendarFirstWeekday: calendar.firstWeekday
        )
        let leading = Array<Date?>(repeating: nil, count: leadingCount)
        let days = (0..<dayCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: interval.start)
        }
        return leading + days.map { Optional($0) }
    }
}

private struct DayDetailSheet: View {
    let day: Date
    @Environment(\.modelContext) private var context
    @Query private var doseLogs: [DoseLog]
    @Query private var sideEffects: [SideEffectLog]
    @Query private var intakeDays: [IntakeDay]
    @Query(sort: \UserSettings.createdAt) private var settingsList: [UserSettings]
    @Query(sort: \WeightEntry.date) private var weightEntries: [WeightEntry]
    @State private var editingEffect: SideEffectLog?
    @State private var editingWeightEntry: WeightEntry?
    @State private var errorMessage: String?

    private var calendar: Calendar { .current }
    private var metric: Bool { settingsList.first?.usesMetric ?? false }
    private var store: TodayStore { TodayStore(context: context) }

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
                    .onDelete { offsets in
                        deleteDoses(logs, at: offsets)
                    }
                }
                Section("Weight") {
                    let dayEntries = weightEntries.filter { calendar.isDate($0.date, inSameDayAs: day) }
                    if dayEntries.isEmpty {
                        Text("No weigh-in logged")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(dayEntries) { entry in
                        Button {
                            editingWeightEntry = entry
                        } label: {
                            Text(UnitFormat.weightString(kilograms: entry.kilograms, metric: metric))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        deleteWeightEntries(dayEntries, at: offsets)
                    }
                }
                Section("Side effects") {
                    let effects = sideEffects.filter { calendar.isDate($0.date, inSameDayAs: day) }
                    if effects.isEmpty {
                        Text("None logged")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(effects) { effect in
                        Button {
                            editingEffect = effect
                        } label: {
                            HStack {
                                Text("\(effect.kind.emoji) \(effect.kind.label)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(severityLabel(effect.severity))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        deleteEffects(effects, at: offsets)
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
            .sheet(item: $editingEffect, onDismiss: { editingEffect = nil }) { effect in
                SideEffectSheet(existing: effect) { kind, severity, note in
                    updateEffect(effect, kind: kind, severity: severity, note: note)
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $editingWeightEntry, onDismiss: { editingWeightEntry = nil }) { entry in
                WeightEntrySheet(metric: metric, entry: entry)
                    .presentationDetents([.medium])
            }
            .alert("Couldn't save", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func severityLabel(_ severity: Int) -> String {
        switch severity {
        case 1: return "Mild"
        case 2: return "Moderate"
        default: return "Severe"
        }
    }

    private func deleteDoses(_ logs: [DoseLog], at offsets: IndexSet) {
        for index in offsets {
            do {
                try store.deleteDose(logs[index])
            } catch {
                errorMessage = "Your change couldn't be saved. Please try again."
            }
        }
    }

    private func deleteEffects(_ effects: [SideEffectLog], at offsets: IndexSet) {
        for index in offsets {
            do {
                try store.deleteSideEffect(effects[index])
            } catch {
                errorMessage = "Your change couldn't be saved. Please try again."
            }
        }
    }

    private func updateEffect(_ effect: SideEffectLog, kind: SideEffectKind, severity: Int, note: String?) {
        do {
            try store.updateSideEffect(effect, kind: kind, severity: severity, note: note)
        } catch {
            errorMessage = "Your change couldn't be saved. Please try again."
        }
    }

    private func deleteWeightEntries(_ entries: [WeightEntry], at offsets: IndexSet) {
        for index in offsets {
            context.delete(entries[index])
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            errorMessage = "Your change couldn't be saved. Please try again."
        }
    }
}
