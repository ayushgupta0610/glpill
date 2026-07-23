import Foundation

struct JourneyVelocity: Equatable {
    let kgPerWeek: Double
    let projectedCompletion: Date?
}

enum JourneyVelocityCalculator {
    /// Average weekly rate of change over the last 4 entries (or fewer),
    /// plus — with >=3 entries and a goal, moving toward it — the projected
    /// date of reaching goalKg by extrapolating that rate. No projection
    /// with fewer entries, no goal, or a rate moving away from the goal.
    static func calculate(entries: [(date: Date, kg: Double)], goalKg: Double?) -> JourneyVelocity {
        let sorted = entries.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return JourneyVelocity(kgPerWeek: 0, projectedCompletion: nil) }

        let window = Array(sorted.suffix(4))
        let first = window.first!
        let last = window.last!
        let days = last.date.timeIntervalSince(first.date) / 86400
        guard days > 0 else { return JourneyVelocity(kgPerWeek: 0, projectedCompletion: nil) }
        let kgPerDay = (last.kg - first.kg) / days
        let kgPerWeek = kgPerDay * 7

        guard let goalKg, sorted.count >= 3, abs(kgPerDay) > 0.001 else {
            return JourneyVelocity(kgPerWeek: kgPerWeek, projectedCompletion: nil)
        }

        let remainingKg = last.kg - goalKg
        let movingTowardGoal = (remainingKg > 0 && kgPerDay < 0) || (remainingKg < 0 && kgPerDay > 0)
        guard movingTowardGoal else {
            return JourneyVelocity(kgPerWeek: kgPerWeek, projectedCompletion: nil)
        }

        let daysRemaining = remainingKg / -kgPerDay
        let projected = Calendar.current.date(byAdding: .day, value: Int(daysRemaining.rounded()), to: last.date)
        return JourneyVelocity(kgPerWeek: kgPerWeek, projectedCompletion: projected)
    }

    /// Direction-based pace label. There's no target date in `UserSettings`,
    /// so this describes trend direction rather than an invented "on/behind
    /// schedule" concept the data can't actually support.
    static func paceLabel(kgPerWeek: Double) -> (text: String, isWarning: Bool) {
        if kgPerWeek < -0.05 {
            return ("Losing steadily", false)
        } else if kgPerWeek > 0.05 {
            return ("Trending up", true)
        } else {
            return ("Holding steady", false)
        }
    }
}
