import Foundation

/// Pure geometry helpers for laying out a month grid that respects the locale's
/// week-start (`Calendar.firstWeekday`), rather than assuming Sunday-first.
enum CalendarLayout {
    /// Number of leading blank cells before the 1st of the month, so the first
    /// day lands under the correct weekday column.
    ///
    /// - Parameters:
    ///   - firstWeekdayOfMonth: `Calendar.component(.weekday,...)` of the 1st
    ///     (1 = Sunday ... 7 = Saturday).
    ///   - calendarFirstWeekday: `Calendar.firstWeekday` (1 = Sunday ... 7 = Saturday).
    static func leadingBlanks(firstWeekdayOfMonth: Int, calendarFirstWeekday: Int) -> Int {
        (firstWeekdayOfMonth - calendarFirstWeekday + 7) % 7
    }
}
