import XCTest
import SwiftData
@testable import GLPill

final class ModelContainerTests: XCTestCase {
    @MainActor
    func testInMemoryContainerCreates() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        XCTAssertNotNil(container.mainContext)
    }

    @MainActor
    func testDoseLogRoundTrip() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let day = Calendar.current.startOfDay(for: .now)
        context.insert(DoseLog(date: day, takenAt: .now, doseMg: 0.8))
        try context.save()
        let logs = try context.fetch(FetchDescriptor<DoseLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.doseMg, 0.8)
        XCTAssertEqual(logs.first?.date, day)
    }

    @MainActor
    func testUserSettingsDefaults() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        context.insert(UserSettings())
        try context.save()
        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertFalse(settings.onboardingComplete)
        XCTAssertEqual(settings.proteinTargetGrams, 100)
        XCTAssertEqual(settings.waterTargetMl, 2000)
    }

    func testMedicationDisplayNameAndEmptyStomach() {
        let foundayo = Medication(kind: .foundayo)
        XCTAssertEqual(foundayo.displayName, "Foundayo (orforglipron)")
        XCTAssertFalse(foundayo.requiresEmptyStomach)

        let rybelsus = Medication(kind: .rybelsus)
        XCTAssertEqual(rybelsus.displayName, "Rybelsus (semaglutide)")
        XCTAssertTrue(rybelsus.requiresEmptyStomach)

        let custom = Medication(kind: .custom, customName: "Compounded Sema")
        XCTAssertEqual(custom.displayName, "Compounded Sema")
        XCTAssertFalse(custom.requiresEmptyStomach)
    }
}
