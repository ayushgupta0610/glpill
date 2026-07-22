import Foundation

enum AdherenceStats {
    /// The longest run of consecutive *expected-but-missed* days in `[from, to]`.
    ///
    /// A day is "expected" from `from` through `min(to, today)` — future days are
    /// never counted as missed. "Missed" means the day is not in `doseDays`.
    static func longestGapDays(
        doseDays: [Date],
        from: Date,
        to: Date,
        calendar: Calendar,
        today: Date = .now
    ) -> Int {
        let start = calendar.startOfDay(for: from)
        let todayDay = calendar.startOfDay(for: today)
        let requestedEnd = calendar.startOfDay(for: to)
        let end = min(requestedEnd, todayDay)
        guard start <= end else { return 0 }

        let dosed = Set(doseDays.map { calendar.startOfDay(for: $0) })

        var longest = 0
        var current = 0
        var cursor = start
        while cursor <= end {
            if dosed.contains(cursor) {
                current = 0
            } else {
                current += 1
                longest = max(longest, current)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return longest
    }
}
