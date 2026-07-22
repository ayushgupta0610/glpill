import Foundation
import SwiftData

/// Builds the widget snapshot from app data and pushes it to the shared container.
@MainActor
enum WidgetSnapshotBuilder {
    /// Pure builder — no store, fully testable.
    static func snapshot(
        doseDays: [Date],
        today: Date,
        medShortName: String,
        doseMg: Double,
        calendar: Calendar
    ) -> GLPillWidgetSnapshot {
        let streak = StreakCalculator.currentStreak(doseDays: doseDays, today: today, calendar: calendar)
        let takenToday = doseDays.contains { calendar.isDate($0, inSameDayAs: today) }
        return GLPillWidgetSnapshot(
            streak: streak,
            doseTakenToday: takenToday,
            medShortName: medShortName,
            doseMg: doseMg
        )
    }

    /// Reads the store, builds the snapshot, and writes it for the widget.
    static func refresh(context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let doseDays = ((try? context.fetch(FetchDescriptor<DoseLog>())) ?? []).map(\.date)

        let medication = ((try? context.fetch(FetchDescriptor<Medication>())) ?? [])
            .sorted { $0.createdAt < $1.createdAt }.first
        let medShort = medication.map { med in
            med.displayName.components(separatedBy: " (").first ?? med.displayName
        } ?? "GLP-1 pill"

        let steps = ((try? context.fetch(FetchDescriptor<TitrationStep>())) ?? [])
            .sorted { $0.order < $1.order }
            .map { (doseMg: $0.doseMg, durationWeeks: $0.durationWeeks) }
        let planStart = ((try? context.fetch(FetchDescriptor<UserSettings>())) ?? [])
            .sorted { $0.startDate < $1.startDate }.first?.startDate ?? now
        var doseMg = 0.0
        if let position = TitrationProgress.position(steps: steps, planStart: planStart, today: now, calendar: calendar),
           position.stepIndex < steps.count {
            doseMg = steps[position.stepIndex].doseMg
        }

        let snapshot = snapshot(doseDays: doseDays, today: now, medShortName: medShort, doseMg: doseMg, calendar: calendar)
        GLPillWidgetBridge.save(snapshot)
    }
}
