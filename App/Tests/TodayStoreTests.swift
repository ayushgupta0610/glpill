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

    /// DI4: intake added at one time of day then again later the same calendar day
    /// resolves to a SINGLE IntakeDay (day-matched, not exact-`Date`-matched).
    @MainActor
    func testIntakeSameCalendarDayResolvesToOneDay() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        var morning = DateComponents()
        morning.year = 2026; morning.month = 3; morning.day = 2; morning.hour = 8
        let am = try XCTUnwrap(store.calendar.date(from: morning))
        var evening = morning
        evening.hour = 20
        let pm = try XCTUnwrap(store.calendar.date(from: evening))

        try store.addProtein(30, on: am)
        try store.addProtein(20, on: pm)

        let days = try context.fetch(FetchDescriptor<IntakeDay>())
        XCTAssertEqual(days.count, 1, "same calendar day must reuse one IntakeDay")
        XCTAssertEqual(days.first?.proteinGrams, 50)
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

    // MARK: - deleteDose

    @MainActor
    func testDeleteDoseRemovesLogAndUndosesDay() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        _ = try store.logDose()
        let logged = try context.fetch(FetchDescriptor<DoseLog>())
        XCTAssertEqual(logged.count, 1)

        try store.deleteDose(logged[0])

        let remaining = try context.fetch(FetchDescriptor<DoseLog>())
        XCTAssertTrue(remaining.isEmpty)

        // Day should no longer be considered "dosed": logging again should succeed.
        XCTAssertNotNil(try? store.logDose())
        let relogged = try context.fetch(FetchDescriptor<DoseLog>())
        XCTAssertEqual(relogged.count, 1)
    }

    // MARK: - deleteSideEffect

    @MainActor
    func testDeleteSideEffectRemovesLog() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        try store.logSideEffect(.nausea, severity: 2, note: "after breakfast")
        let logged = try context.fetch(FetchDescriptor<SideEffectLog>())
        XCTAssertEqual(logged.count, 1)

        try store.deleteSideEffect(logged[0])

        let remaining = try context.fetch(FetchDescriptor<SideEffectLog>())
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: - updateSideEffect

    @MainActor
    func testUpdateSideEffectMutatesSameObject() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        try store.logSideEffect(.nausea, severity: 3, note: "severe")
        let logged = try context.fetch(FetchDescriptor<SideEffectLog>())
        XCTAssertEqual(logged.count, 1)
        let objectID = logged[0].persistentModelID

        try store.updateSideEffect(logged[0], kind: .fatigue, severity: 1, note: "mild now")

        let effects = try context.fetch(FetchDescriptor<SideEffectLog>())
        XCTAssertEqual(effects.count, 1, "update must not create a duplicate")
        XCTAssertEqual(effects.first?.persistentModelID, objectID)
        XCTAssertEqual(effects.first?.kind, .fatigue)
        XCTAssertEqual(effects.first?.severity, 1)
        XCTAssertEqual(effects.first?.note, "mild now")
    }

    @MainActor
    func testUpdateSideEffectClampsSeverity() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        try store.logSideEffect(.nausea, severity: 2)
        let logged = try context.fetch(FetchDescriptor<SideEffectLog>())

        try store.updateSideEffect(logged[0], kind: .nausea, severity: 99, note: nil)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SideEffectLog>()).first?.severity, 3)

        try store.updateSideEffect(logged[0], kind: .nausea, severity: -5, note: nil)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SideEffectLog>()).first?.severity, 1)
    }

    // MARK: - Protein/water clamp at 0

    @MainActor
    func testAddProteinClampsAtZeroOnDecrement() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        try store.addProtein(25)
        try store.addProtein(-10)
        XCTAssertEqual(try context.fetch(FetchDescriptor<IntakeDay>()).first?.proteinGrams, 15)

        try store.addProtein(10)
        try store.addProtein(-50)
        XCTAssertEqual(try context.fetch(FetchDescriptor<IntakeDay>()).first?.proteinGrams, 0)
    }

    @MainActor
    func testAddWaterClampsAtZeroOnDecrement() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        try store.addWater(250)
        try store.addWater(-100)
        XCTAssertEqual(try context.fetch(FetchDescriptor<IntakeDay>()).first?.waterMl, 150)

        try store.addWater(100)
        try store.addWater(-500)
        XCTAssertEqual(try context.fetch(FetchDescriptor<IntakeDay>()).first?.waterMl, 0)
    }

    // MARK: - SideEffectLog date normalization

    @MainActor
    func testLogSideEffectNormalizesDateToStartOfDay() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)
        let now = Date.now

        try store.logSideEffect(.nausea, severity: 2, on: now)

        let effect = try context.fetch(FetchDescriptor<SideEffectLog>()).first
        XCTAssertEqual(effect?.date, store.calendar.startOfDay(for: now))
    }

    // MARK: - logDose calendar-day dedup

    /// Two logs on the SAME calendar day are deduped to one — a re-tap correction.
    @MainActor
    func testLogDoseDedupsSecondLogSameCalendarDay() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        // 9am and 2pm on the same calendar day.
        var morning = DateComponents()
        morning.year = 2026; morning.month = 3; morning.day = 2; morning.hour = 9
        let first = try XCTUnwrap(store.calendar.date(from: morning))
        var afternoon = morning
        afternoon.hour = 14
        let second = try XCTUnwrap(store.calendar.date(from: afternoon))

        _ = try store.logDose(now: first)
        XCTAssertFalse(try store.logDose(now: second))

        let logs = try context.fetch(FetchDescriptor<DoseLog>())
        XCTAssertEqual(logs.count, 1)
    }

    /// DI5: an 11pm dose then a 3am dose the NEXT calendar day (<6h apart) are two
    /// distinct days and BOTH must persist — the old 6h cross-day guard wrongly
    /// blocked this legitimate early next-day dose.
    @MainActor
    func testLogDoseAllowsNextCalendarDayDoseWithinSixHours() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        var lateNight = DateComponents()
        lateNight.year = 2026; lateNight.month = 3; lateNight.day = 2; lateNight.hour = 23
        let first = try XCTUnwrap(store.calendar.date(from: lateNight))

        var earlyMorning = DateComponents()
        earlyMorning.year = 2026; earlyMorning.month = 3; earlyMorning.day = 3; earlyMorning.hour = 3
        let second = try XCTUnwrap(store.calendar.date(from: earlyMorning))

        XCTAssertEqual(second.timeIntervalSince(first), 4 * 60 * 60)
        XCTAssertNotEqual(store.calendar.startOfDay(for: first), store.calendar.startOfDay(for: second))

        _ = try store.logDose(now: first)
        _ = try store.logDose(now: second)

        let logs = try context.fetch(FetchDescriptor<DoseLog>())
        XCTAssertEqual(logs.count, 2, "a next-calendar-day dose <6h later must not be blocked")
    }

    /// A real next-day dose taken on a shifted schedule (e.g. 10pm Monday, then
    /// 8am Tuesday — two distinct calendar days, ~7h apart) must NOT be blocked
    /// by the dup-guard.
    @MainActor
    func testLogDoseAllowsSevenHourCrossMidnightDose() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        var mondayNight = DateComponents()
        mondayNight.year = 2026
        mondayNight.month = 3
        mondayNight.day = 2
        mondayNight.hour = 22
        let first = try XCTUnwrap(store.calendar.date(from: mondayNight))

        var tuesdayMorning = DateComponents()
        tuesdayMorning.year = 2026
        tuesdayMorning.month = 3
        tuesdayMorning.day = 3
        tuesdayMorning.hour = 5
        let second = try XCTUnwrap(store.calendar.date(from: tuesdayMorning))

        XCTAssertEqual(second.timeIntervalSince(first), 7 * 60 * 60)
        XCTAssertNotEqual(store.calendar.startOfDay(for: first), store.calendar.startOfDay(for: second))

        _ = try store.logDose(now: first)
        _ = try store.logDose(now: second)

        let logs = try context.fetch(FetchDescriptor<DoseLog>())
        XCTAssertEqual(logs.count, 2, "a dose 7h later on a new calendar day should be inserted, not blocked as a duplicate")
    }

    @MainActor
    func testLogDoseAllowsLogAfter25Hours() throws {
        let container = try makeContainer(kind: .foundayo)
        let context = container.mainContext
        let store = TodayStore(context: context)

        let first = Date.now
        _ = try store.logDose(now: first)

        let twentyFiveHoursLater = first.addingTimeInterval(25 * 60 * 60)
        _ = try store.logDose(now: twentyFiveHoursLater)

        let logs = try context.fetch(FetchDescriptor<DoseLog>())
        XCTAssertEqual(logs.count, 2, "a dose 25h later is a new day's dose and should be inserted")
    }
}
