import Foundation
import SwiftData

/// Stateless mutation helper for the Today screen. Views own display state;
/// this store owns the write path so it stays unit-testable.
@MainActor
struct TodayStore {
    let context: ModelContext
    var calendar = Calendar.current

    /// Logs today's dose once. Returns true when the empty-stomach eat timer
    /// should start (first log of the day for a medication that requires it).
    @discardableResult
    func logDose(now: Date = .now) throws -> Bool {
        let day = calendar.startOfDay(for: now)
        let existing = try context.fetch(FetchDescriptor<DoseLog>()).first { $0.date == day }
        guard existing == nil else { return false }

        context.insert(DoseLog(date: day, takenAt: now, doseMg: currentDoseMg(on: now)))
        try context.save()
        WidgetSnapshotBuilder.refresh(context: context, now: now, calendar: calendar)

        let medication = try context.fetch(FetchDescriptor<Medication>()).first
        return medication?.requiresEmptyStomach ?? false
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
        day.proteinGrams += grams
        try context.save()
    }

    func addWater(_ ml: Int, on date: Date = .now) throws {
        let day = try intakeDay(for: date)
        day.waterMl += ml
        try context.save()
    }

    func logSideEffect(_ kind: SideEffectKind, severity: Int, note: String? = nil, on date: Date = .now) throws {
        context.insert(SideEffectLog(date: date, kind: kind, severity: severity, note: note))
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
