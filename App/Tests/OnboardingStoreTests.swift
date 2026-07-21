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
