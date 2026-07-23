import XCTest
@testable import GLPill

final class JourneyInsightTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: utc, year: year, month: month, day: day).date!
    }

    func testGeneratesSlowerPaceInsight() {
        let now = date(2026, 3, 15)
        // This month (Feb 15 - Mar 15): -2kg over 18 days -> -0.7778 kg/week.
        // Last month (Jan 15 - Feb 15): -3kg over 21 days -> -1.0 kg/week.
        // |thisRate| < |lastRate| -> "slower", ~22% change.
        let entries: [(date: Date, kg: Double)] = [
            (date(2026, 1, 20), 94.0),
            (date(2026, 2, 10), 91.0),
            (date(2026, 2, 20), 90.0),
            (date(2026, 3, 10), 88.0),
        ]
        let insights = JourneyInsights.generate(entries: entries, now: now, calendar: utc)
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights[0].text, "You're losing weight 22% slower than last month.")
    }

    func testGeneratesFasterPaceInsight() {
        let now = date(2026, 3, 15)
        // This month (Feb 20 - Mar 10): -3kg over 18 days -> -1.1667 kg/week.
        // Last month (Jan 20 - Feb 10): -2kg over 21 days -> -0.6667 kg/week.
        // |thisRate| > |lastRate| -> "faster", 75% change.
        let entries: [(date: Date, kg: Double)] = [
            (date(2026, 1, 20), 94.0),
            (date(2026, 2, 10), 92.0),
            (date(2026, 2, 20), 91.0),
            (date(2026, 3, 10), 88.0),
        ]
        let insights = JourneyInsights.generate(entries: entries, now: now, calendar: utc)
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights[0].text, "You're losing weight 75% faster than last month.")
    }

    func testReturnsEmptyWithInsufficientDataInEitherWindow() {
        let now = date(2026, 3, 15)
        // Only one entry this month.
        let entries: [(date: Date, kg: Double)] = [
            (date(2026, 1, 20), 94.0),
            (date(2026, 2, 10), 91.0),
            (date(2026, 3, 10), 88.0),
        ]
        XCTAssertTrue(JourneyInsights.generate(entries: entries, now: now, calendar: utc).isEmpty)
    }

    func testReturnsEmptyWhenChangeIsBelowNoiseThreshold() {
        let now = date(2026, 3, 15)
        // Last month (Jan 20 - Feb 10): -3kg over 21 days -> exactly -1.0 kg/week.
        // This month (Feb 20 - Mar 10): -2.57kg over 18 days -> -0.9994 kg/week.
        // <5% change -> should not claim a trend.
        let entries: [(date: Date, kg: Double)] = [
            (date(2026, 1, 20), 94.0),
            (date(2026, 2, 10), 91.0),
            (date(2026, 2, 20), 90.0),
            (date(2026, 3, 10), 87.43),
        ]
        XCTAssertTrue(JourneyInsights.generate(entries: entries, now: now, calendar: utc).isEmpty)
    }

    func testReturnsEmptyWhenDirectionFlips() {
        let now = date(2026, 3, 15)
        // Losing last month, gaining this month -> ambiguous to phrase, skip.
        let entries: [(date: Date, kg: Double)] = [
            (date(2026, 1, 20), 90.0),
            (date(2026, 2, 10), 88.0),
            (date(2026, 2, 20), 89.0),
            (date(2026, 3, 10), 91.0),
        ]
        XCTAssertTrue(JourneyInsights.generate(entries: entries, now: now, calendar: utc).isEmpty)
    }

    func testReturnsEmptyWhenPriorRateIsNearZero() {
        let now = date(2026, 3, 15)
        // Prior month (Jan 20 - Feb 10): -0.1kg over 21 days -> priorRate ~= -0.0333 kg/week,
        // well under the 0.05 kg/week noise floor (but nonzero, so it would have slipped
        // past the old `priorRate != 0` guard and blown up the percentage).
        // Recent month (Feb 20 - Mar 10): -3kg over 18 days -> recentRate ~= -1.1667 kg/week.
        let entries: [(date: Date, kg: Double)] = [
            (date(2026, 1, 20), 90.0),
            (date(2026, 2, 10), 89.9),
            (date(2026, 2, 20), 89.0),
            (date(2026, 3, 10), 86.0),
        ]
        XCTAssertTrue(JourneyInsights.generate(entries: entries, now: now, calendar: utc).isEmpty)
    }
}
