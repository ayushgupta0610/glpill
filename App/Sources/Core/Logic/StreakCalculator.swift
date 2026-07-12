import Foundation

enum StreakCalculator {
    /// Consecutive days with a dose ending today, or ending yesterday if
    /// today has no dose yet (the streak stays alive until the day ends).
    static func currentStreak(doseDays: [Date], today: Date, calendar: Calendar) -> Int {
        let days = Set(doseDays.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }

        let todayDay = calendar.startOfDay(for: today)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayDay) else { return 0 }

        let anchor: Date
        if days.contains(todayDay) {
            anchor = todayDay
        } else if days.contains(yesterday) {
            anchor = yesterday
        } else {
            return 0
        }

        var streak = 0
        var cursor = anchor
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func longestStreak(doseDays: [Date], calendar: Calendar) -> Int {
        let days = Set(doseDays.map { calendar.startOfDay(for: $0) }).sorted()
        guard !days.isEmpty else { return 0 }

        var longest = 1
        var current = 1
        for (previous, day) in zip(days, days.dropFirst()) {
            let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? 0
            current = gap == 1 ? current + 1 : 1
            longest = max(longest, current)
        }
        return longest
    }

    /// Percentage (0-100, rounded) of days in [from, to] that have a dose.
    static func adherencePercent(doseDays: [Date], from: Date, to: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        guard start <= end else { return 0 }

        let windowDays = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        let days = Set(doseDays.map { calendar.startOfDay(for: $0) })
        let dosed = days.filter { $0 >= start && $0 <= end }.count
        return Int((Double(dosed) / Double(windowDays) * 100).rounded())
    }
}
