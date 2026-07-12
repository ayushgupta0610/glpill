import XCTest
@testable import GLPill

final class WeightStatsTests: XCTestCase {
    func testTotalChangeNeedsTwoEntries() {
        XCTAssertNil(WeightStats.totalChange(entries: []))
        XCTAssertNil(WeightStats.totalChange(entries: [(Date(), 90.0)]))
    }

    func testTotalChangeIsLatestMinusEarliest() {
        let d1 = Date(timeIntervalSince1970: 1_000)
        let d2 = Date(timeIntervalSince1970: 2_000)
        let d3 = Date(timeIntervalSince1970: 3_000)
        // unsorted input on purpose
        let change = WeightStats.totalChange(entries: [(d2, 88.0), (d1, 90.0), (d3, 86.5)])
        XCTAssertEqual(change!, -3.5, accuracy: 0.0001)
    }

    func testToGoal() {
        XCTAssertEqual(WeightStats.toGoal(current: 86.5, goal: 75.0), 11.5, accuracy: 0.0001)
    }

    func testMilestonesReached() {
        XCTAssertEqual(WeightStats.milestonesReached(startKg: 90, currentKg: 85.9, stepKg: 2), 2)
        XCTAssertEqual(WeightStats.milestonesReached(startKg: 90, currentKg: 90, stepKg: 2), 0)
        XCTAssertEqual(WeightStats.milestonesReached(startKg: 90, currentKg: 92, stepKg: 2), 0)
    }
}
