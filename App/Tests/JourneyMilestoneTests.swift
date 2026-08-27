import XCTest
@testable import GLPill

final class JourneyMilestoneTests: XCTestCase {
    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: Double(offset) * 86400)
    }

    func testGeneratesFiveMilestonesAt20PercentSteps() {
        let entries: [(date: Date, kg: Double)] = [
            (day(0), 100.0),
            (day(7), 95.0),
            (day(14), 90.0),
            (day(21), 85.0),
        ]
        let milestones = JourneyMilestones.generate(startKg: 100, goalKg: 80, entries: entries)

        XCTAssertEqual(milestones.count, 5)
        XCTAssertEqual(milestones.map(\.label), ["20%", "40%", "60%", "80%", "100%"])
        let expectedTargets: [Double] = [96, 92, 88, 84, 80]
        for (actual, expected) in zip(milestones.map(\.targetKg), expectedTargets) {
            XCTAssertEqual(actual, expected, accuracy: 0.0001)
        }
    }

    func testStampsReachedDateFromFirstQualifyingEntry() {
        let entries: [(date: Date, kg: Double)] = [
            (day(0), 100.0),
            (day(7), 95.0),
            (day(14), 90.0),
            (day(21), 85.0),
        ]
        let milestones = JourneyMilestones.generate(startKg: 100, goalKg: 80, entries: entries)

        XCTAssertEqual(milestones[0].reachedDate, day(7))  // 96kg crossed at 95kg
        XCTAssertEqual(milestones[1].reachedDate, day(14)) // 92kg crossed at 90kg
        XCTAssertEqual(milestones[2].reachedDate, day(21)) // 88kg crossed at 85kg
        XCTAssertNil(milestones[3].reachedDate)            // 84kg not yet reached
        XCTAssertNil(milestones[4].reachedDate)            // 80kg not yet reached
        XCTAssertTrue(milestones[0].isReached)
        XCTAssertFalse(milestones[3].isReached)
    }

    func testReturnsEmptyWithoutGoal() {
        let milestones = JourneyMilestones.generate(startKg: 100, goalKg: nil, entries: [])
        XCTAssertTrue(milestones.isEmpty)
    }

    func testReturnsEmptyWhenStartEqualsGoal() {
        let milestones = JourneyMilestones.generate(startKg: 80, goalKg: 80, entries: [])
        XCTAssertTrue(milestones.isEmpty)
    }

    func testUnsortedEntriesAreHandledCorrectly() {
        // Same data as above, shuffled — generate() must sort internally.
        let entries: [(date: Date, kg: Double)] = [
            (day(21), 85.0),
            (day(0), 100.0),
            (day(14), 90.0),
            (day(7), 95.0),
        ]
        let milestones = JourneyMilestones.generate(startKg: 100, goalKg: 80, entries: entries)
        XCTAssertEqual(milestones[0].reachedDate, day(7))
    }
}
