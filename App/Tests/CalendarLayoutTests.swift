import Testing
@testable import GLPill

struct CalendarLayoutTests {
    // Weekday codes: 1 = Sunday, 4 = Wednesday, 7 = Saturday.

    @Test("Sunday-first locale, month starting Wednesday -> 3 blanks")
    func sundayFirstMonthStartsWednesday() {
        #expect(CalendarLayout.leadingBlanks(firstWeekdayOfMonth: 4, calendarFirstWeekday: 1) == 3)
    }

    @Test("Monday-first locale, month starting Wednesday -> 2 blanks")
    func mondayFirstMonthStartsWednesday() {
        #expect(CalendarLayout.leadingBlanks(firstWeekdayOfMonth: 4, calendarFirstWeekday: 2) == 2)
    }

    @Test("Monday-first locale, month starting Sunday -> 6 blanks")
    func mondayFirstMonthStartsSunday() {
        #expect(CalendarLayout.leadingBlanks(firstWeekdayOfMonth: 1, calendarFirstWeekday: 2) == 6)
    }
}
