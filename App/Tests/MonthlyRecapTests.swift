import XCTest
@testable import GLPill

final class MonthlyRecapTests: XCTestCase {

    // MARK: - Archetype selection (each branch)

    func testArchetypeJustStartingWhenTooFewDays() {
        let a = ConsistencyArchetype.select(daysLogged: 3, consistencyPercent: 100, isAllTimeBest: true, hadComeback: false)
        XCTAssertEqual(a, .justStarting)
    }

    func testArchetypeQuietMachineWhenNearlyFlawless() {
        let a = ConsistencyArchetype.select(daysLogged: 20, consistencyPercent: 96, isAllTimeBest: false, hadComeback: false)
        XCTAssertEqual(a, .quietMachine)
    }

    func testArchetypeOnARollWhenAllTimeBest() {
        let a = ConsistencyArchetype.select(daysLogged: 20, consistencyPercent: 80, isAllTimeBest: true, hadComeback: false)
        XCTAssertEqual(a, .onARoll)
    }

    func testArchetypeComebackKidAfterAMiss() {
        let a = ConsistencyArchetype.select(daysLogged: 20, consistencyPercent: 80, isAllTimeBest: false, hadComeback: true)
        XCTAssertEqual(a, .comebackKid)
    }

    func testArchetypeSteadyOneIsTheDefault() {
        let a = ConsistencyArchetype.select(daysLogged: 20, consistencyPercent: 80, isAllTimeBest: false, hadComeback: false)
        XCTAssertEqual(a, .steadyOne)
    }

    // MARK: - Streak milestones

    func testMilestoneNewlyReachedCrossingSeven() {
        XCTAssertEqual(StreakMilestone.newlyReached(streak: 7, lastCelebrated: 0), 7)
    }

    func testMilestoneNotReTriggeredOnceCelebrated() {
        XCTAssertNil(StreakMilestone.newlyReached(streak: 8, lastCelebrated: 7))
    }

    func testMilestoneJumpsToHighestUncelebrated() {
        XCTAssertEqual(StreakMilestone.newlyReached(streak: 30, lastCelebrated: 7), 30)
    }

    func testMilestoneNilBelowFirstThreshold() {
        XCTAssertNil(StreakMilestone.newlyReached(streak: 5, lastCelebrated: 0))
    }

    // MARK: - Recap math

    @MainActor
    func testRecapConsistencyPercentAndArchetype() {
        let recap = RecapBuilder.make(
            monthName: "July",
            daysLogged: 12,
            daysElapsed: 12,
            currentStreak: 12,
            bestStreakThisMonth: 12,
            isAllTimeBest: true,
            hadComeback: false
        )
        XCTAssertEqual(recap.consistencyPercent, 100)
        XCTAssertEqual(recap.archetype, .quietMachine) // 100% wins before all-time-best
        XCTAssertEqual(recap.currentStreak, 12)
    }

    @MainActor
    func testRecapConsistencyRoundsAndClamps() {
        // 10 of 14 days = 71.4% -> 71
        let recap = RecapBuilder.make(
            monthName: "July", daysLogged: 10, daysElapsed: 14,
            currentStreak: 4, bestStreakThisMonth: 6, isAllTimeBest: false, hadComeback: true
        )
        XCTAssertEqual(recap.consistencyPercent, 71)
        XCTAssertEqual(recap.archetype, .comebackKid)
    }

    // MARK: - Privacy guardrail

    @MainActor
    func testRecapCarriesFirstName() {
        let recap = RecapBuilder.make(
            monthName: "July", daysLogged: 20, daysElapsed: 20,
            currentStreak: 20, bestStreakThisMonth: 20, isAllTimeBest: true, hadComeback: false,
            firstName: "Ayush"
        )
        XCTAssertEqual(recap.firstName, "Ayush")
    }

    @MainActor
    func testRecapDropsBlankFirstName() {
        let recap = RecapBuilder.make(
            monthName: "July", daysLogged: 20, daysElapsed: 20,
            currentStreak: 20, bestStreakThisMonth: 20, isAllTimeBest: true, hadComeback: false,
            firstName: "   "
        )
        XCTAssertNil(recap.firstName, "Blank names must normalize to nil")
    }

    @MainActor
    func testRecapExcludesWeightByDefault() {
        let recap = RecapBuilder.make(
            monthName: "July", daysLogged: 20, daysElapsed: 20,
            currentStreak: 20, bestStreakThisMonth: 20, isAllTimeBest: true, hadComeback: false
        )
        XCTAssertNil(recap.weightChangeKg, "Weight must be opt-in — never in the card by default")
        XCTAssertNil(recap.nonScaleVictory)
    }

    // MARK: - daysElapsed denominator (bug: must be based on user's start date, not day-of-month)

    @MainActor
    func testBuildUsesStartDateNotDayOfMonthForDaysElapsed() throws {
        // User onboarded July 27, logged every day (5/5, perfect). "Now" is July 31.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 27)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 12)))

        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        for day in 27...31 {
            let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: 9)))
            context.insert(DoseLog(date: date, takenAt: date, doseMg: 3))
        }
        try context.save()

        let recap = RecapBuilder.build(context: context, now: now, calendar: calendar, startDate: startDate)

        // Days elapsed should be 5 (Jul 27...31), NOT 31 (day-of-month of `now`).
        XCTAssertEqual(recap.daysElapsed, 5)
        XCTAssertEqual(recap.daysLogged, 5)
        XCTAssertEqual(recap.consistencyPercent, 100)
        XCTAssertNotEqual(recap.archetype, .comebackKid, "Perfect attendance must never be mislabeled comeback kid")
    }

    @MainActor
    func testDaysElapsedClampsToStartOfMonthWhenUserStartedEarlier() throws {
        // User started mid-June; recap is for July, so the denominator should be
        // capped at the start of July, not run all the way back to the user's start date.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 12)))

        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext

        let recap = RecapBuilder.build(context: context, now: now, calendar: calendar, startDate: startDate)

        // July 1...10 inclusive = 10 days, not since June 15.
        XCTAssertEqual(recap.daysElapsed, 10)
    }

    @MainActor
    func testMakeComputesComebackCorrectlyWithFixedDaysElapsed() {
        // Sanity check on the pure `make` path: 5 of 5 days is never a comeback.
        let recap = RecapBuilder.make(
            monthName: "July", daysLogged: 5, daysElapsed: 5,
            currentStreak: 5, bestStreakThisMonth: 5, isAllTimeBest: true, hadComeback: false
        )
        XCTAssertEqual(recap.consistencyPercent, 100)
        XCTAssertNotEqual(recap.archetype, .comebackKid)
    }
}
