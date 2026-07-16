import Foundation
import SwiftData

/// The data behind a shareable "Consistency Wrapped" card set. Deliberately holds
/// only consistency/identity data — NEVER the medication name, dose, or weight by
/// default — so the exported artifact is pride, not disclosure. Weight is opt-in
/// only (`weightChangeKg` stays nil unless the user turns it on).
struct MonthlyRecap: Equatable {
    var monthName: String
    var currentStreak: Int
    var bestStreakThisMonth: Int
    var daysLogged: Int
    var daysElapsed: Int
    var consistencyPercent: Int
    var archetype: ConsistencyArchetype
    var nonScaleVictory: String?
    var weightChangeKg: Double?
}

@MainActor
enum RecapBuilder {
    /// Pure assembly — no store, fully testable.
    static func make(
        monthName: String,
        daysLogged: Int,
        daysElapsed: Int,
        currentStreak: Int,
        bestStreakThisMonth: Int,
        isAllTimeBest: Bool,
        hadComeback: Bool,
        nonScaleVictory: String? = nil,
        weightChangeKg: Double? = nil
    ) -> MonthlyRecap {
        let consistency = daysElapsed > 0
            ? min(100, Int((Double(daysLogged) / Double(daysElapsed) * 100).rounded()))
            : 0
        let archetype = ConsistencyArchetype.select(
            daysLogged: daysLogged,
            consistencyPercent: consistency,
            isAllTimeBest: isAllTimeBest,
            hadComeback: hadComeback
        )
        return MonthlyRecap(
            monthName: monthName,
            currentStreak: currentStreak,
            bestStreakThisMonth: bestStreakThisMonth,
            daysLogged: daysLogged,
            daysElapsed: daysElapsed,
            consistencyPercent: consistency,
            archetype: archetype,
            nonScaleVictory: nonScaleVictory,
            weightChangeKg: weightChangeKg
        )
    }

    /// Reads the store and computes this month's recap.
    static func build(
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current,
        includeWeight: Bool = false,
        nonScaleVictory: String? = nil
    ) -> MonthlyRecap {
        let allDoseDays = ((try? context.fetch(FetchDescriptor<DoseLog>())) ?? []).map(\.date)
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let monthDoseDays = allDoseDays.filter { monthInterval?.contains($0) ?? false }

        let daysLogged = Set(monthDoseDays.map { calendar.startOfDay(for: $0) }).count
        let daysElapsed = calendar.component(.day, from: now)
        let currentStreak = StreakCalculator.currentStreak(doseDays: allDoseDays, today: now, calendar: calendar)
        let bestStreakThisMonth = StreakCalculator.longestStreak(doseDays: monthDoseDays, calendar: calendar)
        let longestAll = StreakCalculator.longestStreak(doseDays: allDoseDays, calendar: calendar)
        let isAllTimeBest = currentStreak > 0 && currentStreak >= longestAll
        let hadComeback = daysLogged < daysElapsed && currentStreak >= 3
        let monthName = now.formatted(.dateTime.month(.wide))

        var weightChangeKg: Double? = nil
        if includeWeight {
            let weights = ((try? context.fetch(FetchDescriptor<WeightEntry>())) ?? [])
                .filter { monthInterval?.contains($0.date) ?? false }
                .sorted { $0.date < $1.date }
            if weights.count >= 2, let first = weights.first, let last = weights.last {
                weightChangeKg = last.kilograms - first.kilograms
            }
        }

        return make(
            monthName: monthName,
            daysLogged: daysLogged,
            daysElapsed: daysElapsed,
            currentStreak: currentStreak,
            bestStreakThisMonth: bestStreakThisMonth,
            isAllTimeBest: isAllTimeBest,
            hadComeback: hadComeback,
            nonScaleVictory: nonScaleVictory,
            weightChangeKg: weightChangeKg
        )
    }
}
