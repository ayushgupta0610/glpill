import Testing
import Foundation
@testable import GLPill

struct AdherenceStatsTests {
    private let calendar = Calendar(identifier: .gregorian)

    /// A fixed "today" well in the past so `to` is never clamped by the real now.
    private var anchor: Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!)
    }

    private func day(_ offset: Int) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: anchor)!)
    }

    @Test("No missed days over a fully dosed window is a zero gap")
    func noMissedDays() {
        let days = (0...4).map { day(-$0) } // 5 consecutive dosed days ending at anchor
        let gap = AdherenceStats.longestGapDays(doseDays: days, from: day(-4), to: day(0), calendar: calendar)
        #expect(gap == 0)
    }

    @Test("A single 3-day hole in the middle is a gap of 3")
    func threeDayHoleInMiddle() {
        // Window day(-6)...day(0). Dosed on the ends, missed day(-4), day(-3), day(-2).
        let days = [day(-6), day(-5), day(-1), day(0)]
        let gap = AdherenceStats.longestGapDays(doseDays: days, from: day(-6), to: day(0), calendar: calendar)
        #expect(gap == 3)
    }

    @Test("All days missed is the full window length")
    func allMissed() {
        let gap = AdherenceStats.longestGapDays(doseDays: [], from: day(-4), to: day(0), calendar: calendar)
        #expect(gap == 5)
    }

    @Test("A leading gap longer than a later gap wins")
    func longerLeadingGap() {
        // Window day(-9)...day(0). Leading miss: day(-9)..day(-6) = 4 missed, then dosed day(-5),
        // then a shorter later hole of 2: day(-4), day(-3) missed, dosed day(-2), day(-1), day(0).
        let days = [day(-5), day(-2), day(-1), day(0)]
        let gap = AdherenceStats.longestGapDays(doseDays: days, from: day(-9), to: day(0), calendar: calendar)
        #expect(gap == 4)
    }

    @Test("Empty doses over a 5-day window is a gap of 5")
    func emptyOverFiveDayWindow() {
        let gap = AdherenceStats.longestGapDays(doseDays: [], from: day(-4), to: day(0), calendar: calendar)
        #expect(gap == 5)
    }
}
