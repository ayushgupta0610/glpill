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

    enum OnboardingError: LocalizedError {
        case invalidWeight

        var errorDescription: String? {
            "Please enter a weight between 55–1100 lb (25–500 kg)."
        }
    }

    var kind: MedicationKind = .foundayo
    var customName = ""
    var steps: [DraftStep] = [DraftStep(doseMg: 0.8, durationWeeks: 4)]
    // US-first default: pounds
    var usesMetric = false
    var displayWeight: Double?
    var displayGoal: Double?
    var reminderHour = 9
    var reminderMinute = 0

    func complete(in context: ModelContext, now: Date = .now) throws {
        let startKg = displayWeight.map { UnitFormat.kilograms(fromDisplay: $0, metric: usesMetric) }
        let goalKg = displayGoal.map { UnitFormat.kilograms(fromDisplay: $0, metric: usesMetric) }

        for kg in [startKg, goalKg].compactMap({ $0 }) where !UnitFormat.isValidWeight(kilograms: kg) {
            throw OnboardingError.invalidWeight
        }

        let medication = Medication(kind: kind, customName: kind == .custom ? customName : nil, createdAt: now)
        context.insert(medication)

        for (index, step) in steps.enumerated() where step.doseMg > 0 && step.durationWeeks > 0 {
            context.insert(TitrationStep(order: index, doseMg: step.doseMg, durationWeeks: step.durationWeeks))
        }

        context.insert(UserSettings(
            onboardingComplete: true,
            usesMetric: usesMetric,
            goalKilograms: goalKg,
            startKilograms: startKg,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            startDate: now
        ))

        if let startKg {
            context.insert(WeightEntry(date: now, kilograms: startKg))
        }

        try context.save()
    }
}
