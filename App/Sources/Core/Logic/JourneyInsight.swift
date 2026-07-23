import Foundation

struct JourneyInsight: Equatable {
    let text: String
}

enum JourneyInsights {
    /// Up to one template-filled sentence comparing this month's pace to
    /// last month's. Returns `[]` whenever there isn't enough data to
    /// support a claim, last month's pace is too close to flat to divide by
    /// (<=0.05 kg/week, matching `JourneyVelocityCalculator.paceLabel`'s
    /// "holding steady" floor), the trend direction is ambiguous, or the
    /// change is within noise (<5%) — never fabricates a pace it can't back up.
    static func generate(
        entries: [(date: Date, kg: Double)],
        now: Date,
        calendar: Calendar = .current
    ) -> [JourneyInsight] {
        guard let recentStart = calendar.date(byAdding: .month, value: -1, to: now),
              let priorStart = calendar.date(byAdding: .month, value: -2, to: now) else {
            return []
        }

        let recent = entries.filter { $0.date > recentStart && $0.date <= now }
        let prior = entries.filter { $0.date > priorStart && $0.date <= recentStart }
        guard recent.count >= 2, prior.count >= 2 else { return [] }

        guard let recentRate = weeklyRate(recent), let priorRate = weeklyRate(prior), abs(priorRate) > 0.05 else {
            return []
        }
        guard (recentRate < 0) == (priorRate < 0) else { return [] }

        let percentChange = abs((recentRate - priorRate) / priorRate) * 100
        guard percentChange >= 5 else { return [] }

        let direction = abs(recentRate) > abs(priorRate) ? "faster" : "slower"
        let text = "You're losing weight \(Int(percentChange.rounded()))% \(direction) than last month."
        return [JourneyInsight(text: text)]
    }

    private static func weeklyRate(_ entries: [(date: Date, kg: Double)]) -> Double? {
        let sorted = entries.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        let days = last.date.timeIntervalSince(first.date) / 86400
        // Require at least a full day of separation — entries within the
        // same day produce a near-zero denominator that inflates the rate
        // to a nonsense value (the same bug class fixed in
        // JourneyVelocityCalculator.calculate).
        guard days >= 1 else { return nil }
        return (last.kg - first.kg) / days * 7
    }
}
