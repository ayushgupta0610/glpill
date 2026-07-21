import Foundation

/// Estimated (NOT clinical) relative medication level from logged daily doses,
/// using first-order elimination. Labelled "estimated" wherever shown.
enum MedicationLevel {
    struct Point: Equatable { let date: Date; let level: Double }

    /// Elimination half-lives (hours). Semaglutide ~7 days; orforglipron
    /// published range 29–49 h (using ~40 h midpoint). Estimates for
    /// visualization only, never clinical guidance.
    static func halfLifeHours(for kind: MedicationKind) -> Double {
        switch kind {
        case .rybelsus, .wegovyPill: return 168
        case .foundayo: return 40
        case .custom: return 96
        }
    }

    /// Samples the accumulated level from the first dose to `now`.
    static func curve(doses: [(date: Date, mg: Double)], halfLifeHours: Double, samples: Int, now: Date) -> [Point] {
        guard let first = doses.map(\.date).min(), samples > 1, halfLifeHours > 0 else { return [] }
        let span = now.timeIntervalSince(first)
        guard span > 0 else { return [] }
        let k = log(2) / (halfLifeHours * 3600)
        return (0..<samples).map { i in
            let t = first.addingTimeInterval(span * Double(i) / Double(samples - 1))
            let level = doses.reduce(0.0) { acc, dose in
                let dt = t.timeIntervalSince(dose.date)
                return dt < 0 ? acc : acc + dose.mg * exp(-k * dt)
            }
            return Point(date: t, level: level)
        }
    }

    /// True once the curve is worth showing as a real reading: ≥3 points spanning ≥2 days.
    static func hasEnoughData(points: [Point]) -> Bool {
        guard points.count >= 3, let first = points.first?.date, let last = points.last?.date else { return false }
        return last.timeIntervalSince(first) >= 2 * 86_400
    }

    /// A forward "if you keep taking this daily dose" trajectory — dashed, illustrative.
    static func projection(dailyDoseMg: Double, halfLifeHours: Double, days: Int, samples: Int, startingFrom start: Date) -> [Point] {
        guard dailyDoseMg > 0, days > 0 else { return [] }
        let doses = (0..<days).map { (date: start.addingTimeInterval(Double($0) * 86_400), mg: dailyDoseMg) }
        return curve(doses: doses, halfLifeHours: halfLifeHours, samples: samples, now: start.addingTimeInterval(Double(days - 1) * 86_400))
    }
}
