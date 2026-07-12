import XCTest
import SwiftData
@testable import GLPill

final class TodayStoreTests: XCTestCase {
    @MainActor
    private func makeContainer(kind: MedicationKind) throws -> ModelContainer {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        context.insert(Medication(kind: kind))
        context.insert(TitrationStep(order: 0, doseMg: 0.8, durationWeeks: 4))
        context.insert(UserSettings(onboardingComplete: true, startDate: .now))
        try context.save()
        return container
    }

    @MainActor
    func testLogDoseIsIdempotentPerDay() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        _ = try store.logDose()
        _ = try store.logDose()

        let logs = try context.fetch(FetchDescriptor<DoseLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.doseMg, 0.8)
    }

    @MainActor
    func testRybelsusStartsEatTimerFoundayoDoesNot() throws {
        let rybelsusContainer = try makeContainer(kind: .rybelsus)
        let rybelsusStore = TodayStore(context: rybelsusContainer.mainContext)
        XCTAssertTrue(try rybelsusStore.logDose())

        let foundayoContainer = try makeContainer(kind: .foundayo)
        let foundayoStore = TodayStore(context: foundayoContainer.mainContext)
        XCTAssertFalse(try foundayoStore.logDose())
    }

    @MainActor
    func testSecondLogSameDayDoesNotRestartTimer() throws {
        let container = try makeContainer(kind: .rybelsus)
        let store = TodayStore(context: container.mainContext)
        XCTAssertTrue(try store.logDose())
        XCTAssertFalse(try store.logDose())
    }

    @MainActor
    func testProteinAndWaterAccumulateInSingleRow() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        try store.addProtein(10)
        try store.addProtein(25)
        try store.addWater(250)
        try store.addWater(500)

        let days = try context.fetch(FetchDescriptor<IntakeDay>())
        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days.first?.proteinGrams, 35)
        XCTAssertEqual(days.first?.waterMl, 750)
    }

    @MainActor
    func testLogSideEffect() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        try store.logSideEffect(.nausea, severity: 2, note: "after breakfast")

        let effects = try context.fetch(FetchDescriptor<SideEffectLog>())
        XCTAssertEqual(effects.count, 1)
        XCTAssertEqual(effects.first?.kind, .nausea)
        XCTAssertEqual(effects.first?.severity, 2)
    }
}
