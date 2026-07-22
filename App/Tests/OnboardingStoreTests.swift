import XCTest
import SwiftData
@testable import GLPill

final class OnboardingStoreTests: XCTestCase {
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainerFactory.make(inMemory: true)
    }

    @MainActor
    func testCompletePersistsEverything() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.kind = .rybelsus
        store.steps = [
            OnboardingStore.DraftStep(doseMg: 3, durationWeeks: 4),
            OnboardingStore.DraftStep(doseMg: 7, durationWeeks: 4),
        ]
        store.usesMetric = true
        store.displayWeight = 90
        store.displayGoal = 75
        store.reminderHour = 8
        store.reminderMinute = 15

        try store.complete(in: context)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertTrue(settings.onboardingComplete)
        XCTAssertEqual(settings.startKilograms, 90)
        XCTAssertEqual(settings.goalKilograms, 75)
        XCTAssertEqual(settings.reminderHour, 8)
        XCTAssertEqual(settings.reminderMinute, 15)

        let med = try XCTUnwrap(try context.fetch(FetchDescriptor<Medication>()).first)
        XCTAssertEqual(med.kind, .rybelsus)
        XCTAssertTrue(med.requiresEmptyStomach)

        let steps = try context.fetch(FetchDescriptor<TitrationStep>())
        XCTAssertEqual(steps.count, 2)

        let weights = try context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(weights.count, 1)
        XCTAssertEqual(weights.first?.kilograms, 90)
    }

    @MainActor
    func testCompleteConvertsImperialWeight() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.usesMetric = false
        store.displayWeight = 200

        try store.complete(in: context)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertEqual(settings.startKilograms!, 90.718474, accuracy: 0.0001)
    }

    @MainActor
    func testCompleteRejectsInvalidWeight() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.displayWeight = 10

        XCTAssertThrowsError(try store.complete(in: context))
        XCTAssertTrue(try context.fetch(FetchDescriptor<UserSettings>()).isEmpty)
    }

    @MainActor
    func testCompleteRejectsImplausibleDose() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.steps = [OnboardingStore.DraftStep(doseMg: 800, durationWeeks: 4)]

        XCTAssertThrowsError(try store.complete(in: context))
        XCTAssertTrue(try context.fetch(FetchDescriptor<UserSettings>()).isEmpty)
    }

    @MainActor
    func testCompleteClampsDurationWeeks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.steps = [OnboardingStore.DraftStep(doseMg: 3, durationWeeks: 500)]

        try store.complete(in: context)

        let step = try XCTUnwrap(try context.fetch(FetchDescriptor<TitrationStep>()).first)
        XCTAssertEqual(step.durationWeeks, 52)
    }

    @MainActor
    func testCompletePersistsNormalizedMorningMeds() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.kind = .rybelsus
        store.displayWeight = 180
        store.morningMeds = ["  Thyroid ", "thyroid", ""]

        try store.complete(in: context)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertEqual(settings.morningMeds, ["Thyroid"])
    }

    @MainActor
    func testCompleteRejectsGoalAboveCurrentWeight() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.displayWeight = 200
        store.displayGoal = 210

        XCTAssertThrowsError(try store.complete(in: context)) { error in
            XCTAssertEqual(error as? OnboardingStore.OnboardingError, .goalAboveCurrentWeight)
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<UserSettings>()).isEmpty)
    }

    @MainActor
    func testCompleteRejectsGoalEqualToCurrentWeight() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.displayWeight = 200
        store.displayGoal = 200

        XCTAssertThrowsError(try store.complete(in: context)) { error in
            XCTAssertEqual(error as? OnboardingStore.OnboardingError, .goalAboveCurrentWeight)
        }
    }

    @MainActor
    func testCompleteAllowsGoalBelowCurrentWeight() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.usesMetric = false
        store.displayWeight = 200
        store.displayGoal = 180

        try store.complete(in: context)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertEqual(settings.goalKilograms, UnitFormat.kilograms(fromDisplay: 180, metric: false))
    }

    @MainActor
    func testCompleteAllowsGoalWhenCurrentWeightIsSkipped() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.usesMetric = false
        store.displayWeight = nil
        store.displayGoal = 180

        try store.complete(in: context)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertEqual(settings.goalKilograms, UnitFormat.kilograms(fromDisplay: 180, metric: false))
    }

    @MainActor
    func testCompletePersistsNewOnboardingAnswers() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.kind = .wegovyPill
        store.stage = "switchingFromInjections"
        store.waitWindowMinutes = 45
        store.concerns = ["nausea"]
        store.goals = ["consistency"]
        store.reminderStyle = "pillOnly"
        store.steps = [OnboardingStore.DraftStep(doseMg: 1.5, durationWeeks: 4)]
        try store.complete(in: context)
        let s = try XCTUnwrap(try context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertEqual(s.waitWindowMinutes, 45)
        XCTAssertEqual(s.onboardingStage, "switchingFromInjections")
        XCTAssertEqual(s.sideEffectConcerns, ["nausea"])
        XCTAssertEqual(s.goals, ["consistency"])
        XCTAssertEqual(s.reminderStyle, "pillOnly")
    }

    @MainActor
    func testCompleteWithNoStepsInsertsNoTitrationSteps() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.kind = .foundayo
        store.steps = []

        try store.complete(in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<TitrationStep>()).count, 0)
        XCTAssertNotNil(try context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertNotNil(try context.fetch(FetchDescriptor<Medication>()).first)
    }

    @MainActor
    func testCompleteTwiceUpsertsSingleSettingsAndMedication() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.kind = .rybelsus
        store.displayWeight = 200
        store.usesMetric = false
        store.steps = [OnboardingStore.DraftStep(doseMg: 3, durationWeeks: 4)]

        try store.complete(in: context)
        // Re-run onboarding (e.g. user backs out and finishes again).
        store.displayWeight = 190
        try store.complete(in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<UserSettings>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Medication>()).count, 1)
        // Steps replaced wholesale, not duplicated.
        XCTAssertEqual(try context.fetch(FetchDescriptor<TitrationStep>()).count, 1)
    }

    @MainActor
    func testInvalidDoseLeavesNoOrphanMedication() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.displayWeight = 200
        store.usesMetric = false
        store.steps = [OnboardingStore.DraftStep(doseMg: 800, durationWeeks: 4)]

        XCTAssertThrowsError(try store.complete(in: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<Medication>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TitrationStep>()).count, 0)
        XCTAssertTrue(try context.fetch(FetchDescriptor<UserSettings>()).isEmpty)
    }

    @MainActor
    func testDeduplicateKeepsEarliestUserSettings() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(UserSettings(createdAt: base.addingTimeInterval(200)))
        context.insert(UserSettings(createdAt: base))
        context.insert(UserSettings(createdAt: base.addingTimeInterval(100)))
        try context.save()

        ModelMaintenance.deduplicate(in: context)

        let remaining = try context.fetch(FetchDescriptor<UserSettings>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.createdAt, base)
    }

    /// Merge-then-delete: the canonical (earliest-`createdAt`) row WINS for every
    /// scalar preference — those are never taken from a later row, since a genuine
    /// value can coincide with the model default. Only nil / empty-collection fields
    /// are filled from a later row (and only when `keep` is truly unset).
    @MainActor
    func testDeduplicateMergesComplementaryFieldsIntoEarliest() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        // Earliest (kept) row: firstName + real scalar prefs (some equal defaults).
        let keep = UserSettings(
            createdAt: base,
            usesMetric: false,
            firstName: "Ada",
            reminderHour: 9,
            reminderMinute: 0,
            proteinTargetGrams: 100,
            waterTargetMl: 2000,
            reminderStyle: "full",
            coachingDismissed: false
        )
        // Second row: goal/start weight + metric (nil-fill fields only).
        let second = UserSettings(
            createdAt: base.addingTimeInterval(100),
            usesMetric: true,
            goalKilograms: 70,
            startKilograms: 90
        )
        // Third row: onboarding answers + completion + conflicting scalar prefs
        // that must NOT clobber the canonical row.
        let third = UserSettings(
            createdAt: base.addingTimeInterval(200),
            onboardingComplete: true,
            reminderHour: 7,
            reminderMinute: 30,
            morningMeds: ["Thyroid"],
            onboardingStage: "switchingFromInjections",
            sideEffectConcerns: ["nausea"],
            goals: ["consistency"],
            reminderStyle: "pillOnly",
            coachingDismissed: true
        )
        context.insert(second)
        context.insert(third)
        context.insert(keep)
        try context.save()

        ModelMaintenance.deduplicate(in: context)

        let remaining = try context.fetch(FetchDescriptor<UserSettings>())
        XCTAssertEqual(remaining.count, 1)
        let merged = try XCTUnwrap(remaining.first)
        XCTAssertEqual(merged.createdAt, base)
        // Nil / empty fields filled from later rows.
        XCTAssertEqual(merged.firstName, "Ada")
        XCTAssertEqual(merged.goalKilograms, 70)
        XCTAssertEqual(merged.startKilograms, 90)
        XCTAssertEqual(merged.morningMeds, ["Thyroid"])
        XCTAssertEqual(merged.onboardingStage, "switchingFromInjections")
        XCTAssertEqual(merged.sideEffectConcerns, ["nausea"])
        XCTAssertEqual(merged.goals, ["consistency"])
        // Scalar preferences: canonical row wins, never clobbered.
        XCTAssertFalse(merged.usesMetric)
        XCTAssertEqual(merged.reminderHour, 9)
        XCTAssertEqual(merged.reminderMinute, 0)
        XCTAssertEqual(merged.reminderStyle, "full")
        XCTAssertFalse(merged.coachingDismissed)
        // Completion latches on.
        XCTAssertTrue(merged.onboardingComplete)
    }

    /// A canonical row whose scalar prefs happen to EQUAL the model defaults must not
    /// be overwritten by an `extra` row carrying different (non-default) scalars —
    /// this is the data-loss bug the merge policy guards against.
    @MainActor
    func testDeduplicateCanonicalScalarsSurviveEqualToDefault() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        // Canonical row: reminderStyle="full", 9 AM — genuine values equal to defaults,
        // empty morningMeds.
        let keep = UserSettings(createdAt: base, reminderHour: 9, reminderStyle: "full")
        // Extra: would disable reminders + shift the hour, and carries a med list.
        let extra = UserSettings(
            createdAt: base.addingTimeInterval(100),
            reminderHour: 7,
            morningMeds: ["Thyroid"],
            reminderStyle: "none"
        )
        context.insert(extra)
        context.insert(keep)
        try context.save()

        ModelMaintenance.deduplicate(in: context)

        let remaining = try context.fetch(FetchDescriptor<UserSettings>())
        XCTAssertEqual(remaining.count, 1)
        let merged = try XCTUnwrap(remaining.first)
        // Canonical scalars survive.
        XCTAssertEqual(merged.reminderStyle, "full")
        XCTAssertEqual(merged.reminderHour, 9)
        // Unset collection gets filled from extra.
        XCTAssertEqual(merged.morningMeds, ["Thyroid"])
    }

    /// Re-onboarding must NOT reset the original plan `startDate` (streak/plan start),
    /// and must never reassign the stable `createdAt` identity.
    @MainActor
    func testCompleteTwicePreservesStartDateAndCreatedAt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.kind = .rybelsus
        store.displayWeight = 200
        store.usesMetric = false
        store.steps = [OnboardingStore.DraftStep(doseMg: 3, durationWeeks: 4)]

        let firstNow = Date(timeIntervalSince1970: 1_700_000_000)
        try store.complete(in: context, now: firstNow)
        let original = try XCTUnwrap(try context.fetch(FetchDescriptor<UserSettings>()).first)
        let originalStart = original.startDate
        let originalCreatedAt = original.createdAt
        XCTAssertEqual(originalStart, firstNow)

        // Re-run onboarding a week later.
        let laterNow = firstNow.addingTimeInterval(7 * 24 * 60 * 60)
        store.displayWeight = 190
        try store.complete(in: context, now: laterNow)

        let settings = try context.fetch(FetchDescriptor<UserSettings>())
        XCTAssertEqual(settings.count, 1)
        let updated = try XCTUnwrap(settings.first)
        XCTAssertEqual(updated.startDate, originalStart, "re-onboard must preserve the original plan start")
        XCTAssertEqual(updated.createdAt, originalCreatedAt, "createdAt identity must never change")
        XCTAssertEqual(updated.startKilograms, UnitFormat.kilograms(fromDisplay: 190, metric: false), "other fields still update in place")
    }

    func testDoseValidationBounds() {
        XCTAssertTrue(UnitFormat.isValidDose(mg: 0.05))
        XCTAssertTrue(UnitFormat.isValidDose(mg: 36))
        XCTAssertTrue(UnitFormat.isValidDose(mg: 50))
        XCTAssertFalse(UnitFormat.isValidDose(mg: 0.04))
        XCTAssertFalse(UnitFormat.isValidDose(mg: 50.1))
        XCTAssertFalse(UnitFormat.isValidDose(mg: 0))
        XCTAssertFalse(UnitFormat.isValidDose(mg: -1))
    }
}
