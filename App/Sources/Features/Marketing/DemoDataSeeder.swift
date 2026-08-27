#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only: fills the store with a realistic 12-week journey so the App Store
/// screenshots show the app doing its job instead of empty states. Triggered by the
/// `-seedDemoData` launch argument, always alongside `-resetData`:
///
///     xcrun simctl launch <sim> com.ayushgupta.glpill -resetData -disableCloudKit -seedDemoData
///
/// The screens must be captured from the REAL running app — Guideline 2.3.3 rejects
/// composed marketing images (see `ScreenshotExporter`, which is for social only).
/// Seeding sample *data* is fine; only the *UI* has to be genuine.
enum DemoDataSeeder {
    /// Continuous doses for the last 42 days, then three scattered misses further
    /// back, so the streak reads 42 and 12-week adherence lands just under 100%.
    private static let missedDaysAgo: Set<Int> = [42, 55, 71]
    private static let journeyDays = 84

    static func seed(into context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -(journeyDays - 1), to: today) else { return }

        context.insert(Medication(kind: .rybelsus, createdAt: start))
        seedTitration(into: context, calendar: calendar, today: today)
        seedDoses(into: context, calendar: calendar, today: today)
        seedWeights(into: context, calendar: calendar, today: today)
        seedSideEffects(into: context, calendar: calendar, today: today)
        seedIntake(into: context, calendar: calendar, today: today)

        context.insert(UserSettings(
            createdAt: start,
            onboardingComplete: true,
            usesMetric: false,
            firstName: "Alex",
            goalKilograms: 81.6,   // 180 lb
            startKilograms: 96.2,  // 212 lb
            reminderHour: 7,
            reminderMinute: 30,
            proteinTargetGrams: 120,
            waterTargetMl: 2500,
            startDate: start,
            lastCelebratedMilestone: 30,
            morningMeds: ["Levothyroxine", "Vitamin D"],
            waitWindowMinutes: 30,
            onboardingStage: "I'm a few weeks in",
            sideEffectConcerns: ["Nausea"],
            goals: ["See my weight trend", "Keep records for my doctor"],
            reminderStyle: "full",
            coachingDismissed: false
        ))

        try? context.save()
    }

    // MARK: - Rybelsus 3 → 7 → 14 mg, four weeks per step

    private static func seedTitration(into context: ModelContext, calendar: Calendar, today: Date) {
        let ladder = MedicationLadder.doses(for: .rybelsus)
        for (index, dose) in ladder.enumerated() {
            let weeksBack = journeyDays / 7 - index * 4
            let startDate = calendar.date(byAdding: .day, value: -(weeksBack * 7 - 1), to: today)
            context.insert(TitrationStep(order: index, doseMg: dose, durationWeeks: 4, startDate: startDate))
        }
    }

    private static func doseMg(daysAgo: Int) -> Double {
        switch daysAgo {
        case 0..<28: return 14
        case 28..<56: return 7
        default: return 3
        }
    }

    private static func seedDoses(into context: ModelContext, calendar: Calendar, today: Date) {
        for daysAgo in 0..<journeyDays where !missedDaysAgo.contains(daysAgo) {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            // Taken a little after the 7:30 reminder, drifting a few minutes day to day.
            let minutes = 30 + (daysAgo * 7) % 25
            let takenAt = calendar.date(bySettingHour: 7, minute: minutes, second: 0, of: day) ?? day
            context.insert(DoseLog(date: day, takenAt: takenAt, doseMg: doseMg(daysAgo: daysAgo)))
        }
    }

    // MARK: - 96.2 kg → 87.4 kg over 12 weeks, with the plateaus real journeys have

    private static func seedWeights(into context: ModelContext, calendar: Calendar, today: Date) {
        let startKg = 96.2
        let endKg = 87.4
        // Weigh-ins every three days, easing so early loss is faster than late.
        for daysAgo in stride(from: journeyDays - 1, through: 0, by: -3) {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let elapsed = Double(journeyDays - 1 - daysAgo) / Double(journeyDays - 1)
            let eased = 1 - pow(1 - elapsed, 1.6)
            // Deterministic ±0.35 kg wobble so the trend line reads as real weigh-ins.
            let wobble = sin(Double(daysAgo) * 1.7) * 0.35
            let kg = startKg - (startKg - endKg) * eased + wobble
            let takenAt = calendar.date(bySettingHour: 7, minute: 10, second: 0, of: day) ?? day
            context.insert(WeightEntry(date: takenAt, kilograms: (kg * 10).rounded() / 10))
        }
    }

    // MARK: - Nausea early in each dose step, fading as the body adjusts

    private static func seedSideEffects(into context: ModelContext, calendar: Calendar, today: Date) {
        let entries: [(daysAgo: Int, kind: SideEffectKind, severity: Int, note: String?)] = [
            (80, .nausea, 2, "Worst in the first hour after the pill."),
            (77, .nausea, 2, nil),
            (74, .fatigue, 1, nil),
            (69, .nausea, 1, "Much milder this week."),
            (54, .nausea, 2, "Came back after moving up to 7 mg."),
            (50, .reflux, 1, nil),
            (44, .nausea, 1, nil),
            (26, .nausea, 2, "First few days on 14 mg."),
            (22, .constipation, 1, nil),
            (11, .fatigue, 1, "Afternoon slump."),
        ]
        for entry in entries {
            guard let day = calendar.date(byAdding: .day, value: -entry.daysAgo, to: today) else { continue }
            let at = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day) ?? day
            context.insert(SideEffectLog(date: at, kind: entry.kind, severity: entry.severity, note: entry.note))
        }
    }

    // MARK: - Protein and water for the last two weeks, today mid-progress

    private static func seedIntake(into context: ModelContext, calendar: Calendar, today: Date) {
        for daysAgo in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            // Today is captured mid-afternoon so the rings are filling, not full.
            let protein = daysAgo == 0 ? 96 : 108 + (daysAgo * 11) % 26
            let water = daysAgo == 0 ? 1800 : 2200 + (daysAgo * 130) % 500
            context.insert(IntakeDay(date: day, proteinGrams: protein, waterMl: water))
        }
    }
}
#endif
