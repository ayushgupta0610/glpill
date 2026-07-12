import XCTest
@testable import GLPill

final class StreakCalculatorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ offset: Int, from base: Date = .now) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: base)!)
    }

    func testEmptyLogsGiveZeroStreak() {
        XCTAssertEqual(StreakCalculator.currentStreak(doseDays: [], today: .now, calendar: calendar), 0)
    }

    func testTodayOnlyGivesOne() {
        XCTAssertEqual(StreakCalculator.currentStreak(doseDays: [day(0)], today: .now, calendar: calendar), 1)
    }

    func testTodayAndYesterdayGivesTwo() {
        XCTAssertEqual(StreakCalculator.currentStreak(doseDays: [day(-1), day(0)], today: .now, calendar: calendar), 2)
    }

    func testGapBreaksStreak() {
        XCTAssertEqual(StreakCalculator.currentStreak(doseDays: [day(-3), day(-1), day(0)], today: .now, calendar: calendar), 2)
    }

    func testLoggedYesterdayButNotTodayKeepsStreakAlive() {
        XCTAssertEqual(StreakCalculator.currentStreak(doseDays: [day(-2), day(-1)], today: .now, calendar: calendar), 2)
    }

    func testMissedYesterdayAndTodayGivesZero() {
        XCTAssertEqual(StreakCalculator.currentStreak(doseDays: [day(-3), day(-2)], today: .now, calendar: calendar), 0)
    }

    func testDuplicateSameDayCountsOnce() {
        XCTAssertEqual(StreakCalculator.currentStreak(doseDays: [day(0), day(0), day(-1)], today: .now, calendar: calendar), 2)
    }

    func testLongestStreak() {
        let days = [day(-9), day(-8), day(-7), day(-5), day(-1), day(0)]
        XCTAssertEqual(StreakCalculator.longestStreak(doseDays: days, calendar: calendar), 3)
    }

    func testLongestStreakEmpty() {
        XCTAssertEqual(StreakCalculator.longestStreak(doseDays: [], calendar: calendar), 0)
    }

    func testAdherencePercentFullWindow() {
        let days = (0...27).map { day(-$0) }
        XCTAssertEqual(StreakCalculator.adherencePercent(doseDays: days, from: day(-27), to: day(0), calendar: calendar), 100)
    }

    func testAdherencePercentPartial() {
        // 24 of 28 days
        let days = (0...23).map { day(-$0) }
        XCTAssertEqual(StreakCalculator.adherencePercent(doseDays: days, from: day(-27), to: day(0), calendar: calendar), 86)
    }

    func testAdherencePercentEmptyWindow() {
        XCTAssertEqual(StreakCalculator.adherencePercent(doseDays: [], from: day(-27), to: day(0), calendar: calendar), 0)
    }
}
