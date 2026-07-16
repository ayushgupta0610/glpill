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
    func testRecapExcludesWeightByDefault() {
        let recap = RecapBuilder.make(
            monthName: "July", daysLogged: 20, daysElapsed: 20,
            currentStreak: 20, bestStreakThisMonth: 20, isAllTimeBest: true, hadComeback: false
        )
        XCTAssertNil(recap.weightChangeKg, "Weight must be opt-in — never in the card by default")
        XCTAssertNil(recap.nonScaleVictory)
    }
}
