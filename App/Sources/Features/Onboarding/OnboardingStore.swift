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
    var steps: [DraftStep] = [DraftStep(doseMg: 0.8, durationWeeks: 4)]
    // US-first default: pounds
    var usesMetric = false
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

        for kg in [startKg, goalKg].compactMap({ $0 }) where !UnitFormat.isValidWeight(kilograms: kg) {
            throw OnboardingError.invalidWeight
        }

        if let startKg, let goalKg, goalKg >= startKg {
            throw OnboardingError.goalAboveCurrentWeight
        }

        let medication = Medication(kind: kind, customName: kind == .custom ? customName : nil, createdAt: now)
        context.insert(medication)

        if steps.contains(where: { !UnitFormat.isValidDose(mg: $0.doseMg) }) {
            throw OnboardingError.invalidDose
        }
        for (index, step) in steps.enumerated() {
            context.insert(TitrationStep(
                order: index,
                doseMg: step.doseMg,
                durationWeeks: min(max(step.durationWeeks, 1), 52)
            ))
        }

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

        if let startKg {
            context.insert(WeightEntry(date: now, kilograms: startKg))
        }

        try context.save()
    }
}
