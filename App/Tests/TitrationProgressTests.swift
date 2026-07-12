import XCTest
@testable import GLPill

final class TitrationProgressTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private var planStart: Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!)
    }

    private func date(_ daysAfterStart: Int) -> Date {
        calendar.date(byAdding: .day, value: daysAfterStart, to: planStart)!
    }

    private let steps: [(doseMg: Double, durationWeeks: Int)] = [
        (0.8, 4), (1.6, 4), (3.2, 4)
    ]

    func testEmptyStepsGiveNil() {
        XCTAssertNil(TitrationProgress.position(steps: [], planStart: planStart, today: .now, calendar: calendar))
    }

    func testDayZeroIsFirstStepDayZero() {
        let pos = TitrationProgress.position(steps: steps, planStart: planStart, today: date(0), calendar: calendar)
        XCTAssertEqual(pos, TitrationPosition(stepIndex: 0, dayWithinStep: 0, nextStepDate: date(28)))
    }

    func testMidFirstStep() {
        let pos = TitrationProgress.position(steps: steps, planStart: planStart, today: date(10), calendar: calendar)
        XCTAssertEqual(pos?.stepIndex, 0)
        XCTAssertEqual(pos?.dayWithinStep, 10)
    }

    func testBoundaryDayStartsNextStep() {
        let pos = TitrationProgress.position(steps: steps, planStart: planStart, today: date(28), calendar: calendar)
        XCTAssertEqual(pos, TitrationPosition(stepIndex: 1, dayWithinStep: 0, nextStepDate: date(56)))
    }

    func testBeyondLastStepStaysOnLastStep() {
        let pos = TitrationProgress.position(steps: steps, planStart: planStart, today: date(200), calendar: calendar)
        XCTAssertEqual(pos?.stepIndex, 2)
        XCTAssertNil(pos?.nextStepDate)
    }

    func testTodayBeforePlanStartClampsToDayZero() {
        let pos = TitrationProgress.position(steps: steps, planStart: planStart, today: date(-5), calendar: calendar)
        XCTAssertEqual(pos?.stepIndex, 0)
        XCTAssertEqual(pos?.dayWithinStep, 0)
    }
}
