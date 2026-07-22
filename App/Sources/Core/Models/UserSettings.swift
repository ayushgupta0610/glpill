import Foundation
import SwiftData

@Model
final class UserSettings {
    /// Immutable stable identity for the singleton-ish row. CloudKit can create a
    /// second row per device before syncing; the canonical row is the one with the
    /// earliest `createdAt`. Never mutate this after creation — dedup and every
    /// reader/writer key on it (unlike `startDate`, which re-onboarding overwrites).
    var createdAt: Date = Date.now
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
    /// Optional list of the user's OTHER morning medications (names only). Used to
    /// tell them when their empty-stomach window is clear. Timing metadata, not advice.
    var morningMeds: [String] = []
    var waitWindowMinutes: Int = 30
    var onboardingStage: String?
    var sideEffectConcerns: [String] = []
    var goals: [String] = []
    var reminderStyle: String = "full"
    var coachingDismissed: Bool = false

    init(
        createdAt: Date = .now,
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
        lastCelebratedMilestone: Int = 0,
        morningMeds: [String] = [],
        waitWindowMinutes: Int = 30,
        onboardingStage: String? = nil,
        sideEffectConcerns: [String] = [],
        goals: [String] = [],
        reminderStyle: String = "full",
        coachingDismissed: Bool = false
    ) {
        self.createdAt = createdAt
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
        self.morningMeds = morningMeds
        self.waitWindowMinutes = waitWindowMinutes
        self.onboardingStage = onboardingStage
        self.sideEffectConcerns = sideEffectConcerns
        self.goals = goals
        self.reminderStyle = reminderStyle
        self.coachingDismissed = coachingDismissed
    }
}

extension UserSettings {
    /// The canonical row — earliest `createdAt`. Use at every non-`@Query` fetch site
    /// so all readers/writers agree on which row wins during a CloudKit merge window.
    static func canonical(in context: ModelContext) -> UserSettings? {
        ((try? context.fetch(FetchDescriptor<UserSettings>())) ?? [])
            .min { $0.createdAt < $1.createdAt }
    }
}
