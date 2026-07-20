import Foundation
import SwiftData

/// Stateless mutation helper for the Today screen. Views own display state;
/// this store owns the write path so it stays unit-testable.
@MainActor
struct TodayStore {
    let context: ModelContext
    var calendar = Calendar.current

    /// A once-daily pill can't legitimately be re-taken within this window, even if
    /// a timezone change causes "today" to recompute to a different calendar day.
    private static let minHoursBetweenDoses: TimeInterval = 20 * 60 * 60

    /// Logs today's dose once. Returns true when the empty-stomach eat timer
    /// should start (first log of the day for a medication that requires it).
    @discardableResult
    func logDose(now: Date = .now) throws -> Bool {
        let day = calendar.startOfDay(for: now)
        let existingLogs = try context.fetch(FetchDescriptor<DoseLog>())
        let isDuplicate = existingLogs.contains {
            $0.date == day || abs($0.takenAt.timeIntervalSince(now)) < Self.minHoursBetweenDoses
        }
        guard !isDuplicate else { return false }

        context.insert(DoseLog(date: day, takenAt: now, doseMg: currentDoseMg(on: now)))
        try context.save()
        WidgetSnapshotBuilder.refresh(context: context, now: now, calendar: calendar)

        let medication = try context.fetch(FetchDescriptor<Medication>()).first
        return medication?.requiresEmptyStomach ?? false
    }

    /// Deletes a logged dose (user correction) and refreshes the widget snapshot.
    func deleteDose(_ log: DoseLog, now: Date = .now) throws {
        context.delete(log)
        try context.save()
        WidgetSnapshotBuilder.refresh(context: context, now: now, calendar: calendar)
    }

    func currentDoseMg(on date: Date = .now) -> Double {
        let steps = ((try? context.fetch(FetchDescriptor<TitrationStep>())) ?? [])
            .sorted { $0.order < $1.order }
            .map { (doseMg: $0.doseMg, durationWeeks: $0.durationWeeks) }
        let planStart = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first?.startDate ?? date
        guard let position = TitrationProgress.position(steps: steps, planStart: planStart, today: date, calendar: calendar),
              position.stepIndex < steps.count else { return 0 }
        return steps[position.stepIndex].doseMg
    }

    func addProtein(_ grams: Int, on date: Date = .now) throws {
        let day = try intakeDay(for: date)
        day.proteinGrams = max(0, day.proteinGrams + grams)
        try context.save()
    }

    func addWater(_ ml: Int, on date: Date = .now) throws {
        let day = try intakeDay(for: date)
        day.waterMl = max(0, day.waterMl + ml)
        try context.save()
    }

    func logSideEffect(_ kind: SideEffectKind, severity: Int, note: String? = nil, on date: Date = .now) throws {
        context.insert(SideEffectLog(date: calendar.startOfDay(for: date), kind: kind, severity: severity, note: note))
        try context.save()
    }

    /// Deletes a logged side effect (user correction).
    func deleteSideEffect(_ log: SideEffectLog) throws {
        context.delete(log)
        try context.save()
    }

    /// Updates a logged side effect in place (user correction) — no duplicate is created.
    func updateSideEffect(_ log: SideEffectLog, kind: SideEffectKind, severity: Int, note: String?) throws {
        log.kindRaw = kind.rawValue
        log.severity = min(max(severity, 1), 3)
        log.note = note
        try context.save()
    }

    private func intakeDay(for date: Date) throws -> IntakeDay {
        let day = calendar.startOfDay(for: date)
        if let existing = try context.fetch(FetchDescriptor<IntakeDay>()).first(where: { $0.date == day }) {
            return existing
        }
        let created = IntakeDay(date: day)
        context.insert(created)
        return created
    }
}
