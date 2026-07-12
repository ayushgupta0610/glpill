import Foundation
import SwiftData

@Model
final class UserSettings {
    var onboardingComplete: Bool
    var usesMetric: Bool
    var goalKilograms: Double?
    var startKilograms: Double?
    var reminderHour: Int
    var reminderMinute: Int
    var proteinTargetGrams: Int
    var waterTargetMl: Int
    var startDate: Date

    init(
        onboardingComplete: Bool = false,
        usesMetric: Bool = false,
        goalKilograms: Double? = nil,
        startKilograms: Double? = nil,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        proteinTargetGrams: Int = 100,
        waterTargetMl: Int = 2000,
        startDate: Date = .now
    ) {
        self.onboardingComplete = onboardingComplete
        self.usesMetric = usesMetric
        self.goalKilograms = goalKilograms
        self.startKilograms = startKilograms
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.proteinTargetGrams = proteinTargetGrams
        self.waterTargetMl = waterTargetMl
        self.startDate = startDate
    }
}
