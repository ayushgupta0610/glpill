import XCTest
@testable import GLPill

final class JourneyVelocityTests: XCTestCase {
    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: Double(offset) * 86400)
    }

    func testFewerThanTwoEntriesGivesZeroVelocityNoProjection() {
        let empty = JourneyVelocityCalculator.calculate(entries: [], goalKg: 80)
        XCTAssertEqual(empty.kgPerWeek, 0, accuracy: 0.0001)
        XCTAssertNil(empty.projectedCompletion)

        let single = JourneyVelocityCalculator.calculate(entries: [(day(0), 90.0)], goalKg: 80)
        XCTAssertEqual(single.kgPerWeek, 0, accuracy: 0.0001)
        XCTAssertNil(single.projectedCompletion)
    }

    func testTwoEntriesComputeRateButNoProjection() {
        // -0.2 kg/day over 7 days = -1.4 kg/week; needs >=3 entries to project.
        let entries: [(date: Date, kg: Double)] = [(day(0), 90.0), (day(7), 88.6)]
        let result = JourneyVelocityCalculator.calculate(entries: entries, goalKg: 80)
        XCTAssertEqual(result.kgPerWeek, -1.4, accuracy: 0.0001)
        XCTAssertNil(result.projectedCompletion)
    }

    func testThreeEntriesProjectCompletionDate() {
        // Constant -0.2 kg/day. Last entry 87.2kg at day 14, goal 80kg.
        // remaining = 7.2kg, days to close = 7.2 / 0.2 = 36 -> day 50.
        let entries: [(date: Date, kg: Double)] = [
            (day(0), 90.0), (day(7), 88.6), (day(14), 87.2),
        ]
        let result = JourneyVelocityCalculator.calculate(entries: entries, goalKg: 80)
        XCTAssertEqual(result.kgPerWeek, -1.4, accuracy: 0.0001)
        XCTAssertEqual(result.projectedCompletion, day(50))
    }

    func testNoProjectionWhenMovingAwayFromGoal() {
        // Gaining weight while goal is below start -> never projected.
        let entries: [(date: Date, kg: Double)] = [
            (day(0), 90.0), (day(7), 91.0), (day(14), 92.0),
        ]
        let result = JourneyVelocityCalculator.calculate(entries: entries, goalKg: 80)
        XCTAssertEqual(result.kgPerWeek, 1.0, accuracy: 0.0001)
        XCTAssertNil(result.projectedCompletion)
    }

    func testNoProjectionWithoutGoal() {
        let entries: [(date: Date, kg: Double)] = [
            (day(0), 90.0), (day(7), 88.6), (day(14), 87.2),
        ]
        let result = JourneyVelocityCalculator.calculate(entries: entries, goalKg: nil)
        XCTAssertNil(result.projectedCompletion)
    }

    func testSameDayEntriesDoNotProduceBlownUpRate() {
        // Regression test: two entries logged hours apart on the same day
        // (e.g. a correction) must not blow up kgPerWeek via a near-zero
        // days denominator. Found in manual verification: a real run with
        // same-day entries produced "123542.7 kg/week" instead of a sane
        // value.
        let sameDay = Date(timeIntervalSince1970: 10 * 86400)
        let hoursLater = sameDay.addingTimeInterval(3 * 3600)
        let entries: [(date: Date, kg: Double)] = [(sameDay, 90.0), (hoursLater, 89.5)]
        let result = JourneyVelocityCalculator.calculate(entries: entries, goalKg: 80)
        XCTAssertEqual(result.kgPerWeek, 0, accuracy: 0.0001)
        XCTAssertNil(result.projectedCompletion)
    }

    func testPaceLabels() {
        XCTAssertEqual(JourneyVelocityCalculator.paceLabel(kgPerWeek: -0.5).text, "Losing steadily")
        XCTAssertFalse(JourneyVelocityCalculator.paceLabel(kgPerWeek: -0.5).isWarning)

        XCTAssertEqual(JourneyVelocityCalculator.paceLabel(kgPerWeek: 0.5).text, "Trending up")
        XCTAssertTrue(JourneyVelocityCalculator.paceLabel(kgPerWeek: 0.5).isWarning)

        XCTAssertEqual(JourneyVelocityCalculator.paceLabel(kgPerWeek: 0.01).text, "Holding steady")
        XCTAssertFalse(JourneyVelocityCalculator.paceLabel(kgPerWeek: 0.01).isWarning)
    }
}
