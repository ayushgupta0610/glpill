import Foundation

/// A single progress checkpoint between a journey's start and goal weight.
struct JourneyMilestone: Identifiable, Equatable {
    let id: Int
    let label: String
    let targetKg: Double
    let reachedDate: Date?

    var isReached: Bool { reachedDate != nil }
}

enum JourneyMilestones {
    private static let fractions: [Double] = [0.2, 0.4, 0.6, 0.8, 1.0]

    /// Five milestones at 20% increments of the start→goal distance, each
    /// stamped with the date weight first crossed that target (nil if not
    /// yet reached). Returns `[]` when there's no goal or start == goal —
    /// there's nothing to divide into steps.
    static func generate(
        startKg: Double,
        goalKg: Double?,
        entries: [(date: Date, kg: Double)]
    ) -> [JourneyMilestone] {
        guard let goalKg, startKg != goalKg else { return [] }
        let losing = goalKg < startKg
        let sortedEntries = entries.sorted { $0.date < $1.date }

        return fractions.enumerated().map { index, fraction in
            let targetKg = startKg + (goalKg - startKg) * fraction
            let reached = sortedEntries.first { losing ? $0.kg <= targetKg : $0.kg >= targetKg }
            return JourneyMilestone(
                id: index,
                label: "\(Int((fraction * 100).rounded()))%",
                targetKg: targetKg,
                reachedDate: reached?.date
            )
        }
    }
}
