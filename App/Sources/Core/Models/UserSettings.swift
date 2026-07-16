import Foundation
import SwiftData

@Model
final class UserSettings {
    var onboardingComplete: Bool = false
    var usesMetric: Bool = false
    /// Optional first name for personalizing the shareable recap card. Stored
    /// only on-device (+ the user's own private iCloud) — never sent anywhere.
    var firstName: String?
    var goalKilograms: Double?
    var startKilograms: Double?
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var proteinTargetGrams: Int = 100
    var waterTargetMl: Int = 2000
    var startDate: Date = Date.now
    /// Highest streak milestone (7/30/100/365) already celebrated, so the Trophy
    /// Card fires once per milestone rather than on every dose log.
    var lastCelebratedMilestone: Int = 0

    init(
        onboardingComplete: Bool = false,
        usesMetric: Bool = false,
        firstName: String? = nil,
        goalKilograms: Double? = nil,
        startKilograms: Double? = nil,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        proteinTargetGrams: Int = 100,
        waterTargetMl: Int = 2000,
        startDate: Date = .now,
        lastCelebratedMilestone: Int = 0
    ) {
        self.onboardingComplete = onboardingComplete
        self.usesMetric = usesMetric
        self.firstName = firstName
        self.goalKilograms = goalKilograms
        self.startKilograms = startKilograms
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.proteinTargetGrams = proteinTargetGrams
        self.waterTargetMl = waterTargetMl
        self.startDate = startDate
        self.lastCelebratedMilestone = lastCelebratedMilestone
    }
}
