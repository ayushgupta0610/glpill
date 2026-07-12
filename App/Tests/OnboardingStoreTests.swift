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
}
