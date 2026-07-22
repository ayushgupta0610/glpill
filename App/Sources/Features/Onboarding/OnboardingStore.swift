import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class OnboardingStore {
    struct DraftStep: Identifiable {
        let id = UUID()
        var doseMg: Double
        var durationWeeks: Int
    }

    enum OnboardingError: LocalizedError, Equatable {
        case invalidWeight
        case invalidDose
        case goalAboveCurrentWeight

        var errorDescription: String? {
            switch self {
            case .invalidWeight:
                return "Please enter a weight between 55–1100 lb (25–500 kg)."
            case .invalidDose:
                return "Dose steps must be between 0.05 and 50 mg. Double-check your prescriber's plan."
            case .goalAboveCurrentWeight:
                return "Goal weight should be below your current weight."
            }
        }
    }

    var kind: MedicationKind = .foundayo
    var customName = ""
    var steps: [DraftStep] = []
    // Default to the device's measurement system (weight step was removed from
    // onboarding, so this is the only place units get inferred); user can still
    // switch in Settings.
    var usesMetric = Locale.current.measurementSystem == .metric
    var displayWeight: Double?
    var displayGoal: Double?
    var morningMeds: [String] = []
    var reminderHour = 9
    var reminderMinute = 0
    var stage: String?
    var waitWindowMinutes = 30
    var concerns: [String] = []
    var goals: [String] = []
    var reminderStyle = "full"
    /// Convenience for the conditional wait-window step.
    var requiresEmptyStomach: Bool { kind.defaultRequiresEmptyStomach }

    func complete(in context: ModelContext, now: Date = .now) throws {
        let startKg = displayWeight.map { UnitFormat.kilograms(fromDisplay: $0, metric: usesMetric) }
        let goalKg = displayGoal.map { UnitFormat.kilograms(fromDisplay: $0, metric: usesMetric) }

        // Validate everything BEFORE any insert so a throw leaves no partial rows
        // behind (no orphaned Medication/TitrationSteps to duplicate on retry).
        for kg in [startKg, goalKg].compactMap({ $0 }) where !UnitFormat.isValidWeight(kilograms: kg) {
            throw OnboardingError.invalidWeight
        }

        if let startKg, let goalKg, goalKg >= startKg {
            throw OnboardingError.goalAboveCurrentWeight
        }

        if steps.contains(where: { !UnitFormat.isValidDose(mg: $0.doseMg) }) {
            throw OnboardingError.invalidDose
        }

        // Upsert the medication: re-running onboarding updates the existing row in
        // place rather than inserting a second one.
        let normalizedCustom = kind == .custom ? MedicationName.normalize(customName) : nil
        if let existing = try context.fetch(FetchDescriptor<Medication>())
            .sorted(by: { $0.createdAt < $1.createdAt }).first {
            existing.kindRaw = kind.rawValue
            existing.customName = normalizedCustom
        } else {
            context.insert(Medication(kind: kind, customName: normalizedCustom, createdAt: now))
        }

        // Replace titration steps wholesale (they're plan-scoped, not identity-scoped).
        for step in try context.fetch(FetchDescriptor<TitrationStep>()) {
            context.delete(step)
        }
        for (index, step) in steps.enumerated() {
            context.insert(TitrationStep(
                order: index,
                doseMg: step.doseMg,
                durationWeeks: min(max(step.durationWeeks, 1), 52)
            ))
        }

        // Upsert user settings: update the earliest existing row in place if present.
        if let settings = try context.fetch(FetchDescriptor<UserSettings>())
            .sorted(by: { $0.startDate < $1.startDate }).first {
            settings.onboardingComplete = true
            settings.usesMetric = usesMetric
            settings.goalKilograms = goalKg
            settings.startKilograms = startKg
            settings.reminderHour = reminderHour
            settings.reminderMinute = reminderMinute
            settings.startDate = now
            settings.morningMeds = MorningMeds.normalize(morningMeds)
            settings.waitWindowMinutes = waitWindowMinutes
            settings.onboardingStage = stage
            settings.sideEffectConcerns = concerns
            settings.goals = goals
            settings.reminderStyle = reminderStyle
        } else {
            context.insert(UserSettings(
                onboardingComplete: true,
                usesMetric: usesMetric,
                goalKilograms: goalKg,
                startKilograms: startKg,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute,
                startDate: now,
                morningMeds: MorningMeds.normalize(morningMeds),
                waitWindowMinutes: waitWindowMinutes,
                onboardingStage: stage,
                sideEffectConcerns: concerns,
                goals: goals,
                reminderStyle: reminderStyle
            ))
        }

        if let startKg {
            context.insert(WeightEntry(date: now, kilograms: startKg))
        }

        try context.save()
    }
}
