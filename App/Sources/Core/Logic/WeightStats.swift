import Foundation

enum WeightStats {
    /// Latest weight minus earliest weight (negative = loss). Nil with fewer than 2 entries.
    static func totalChange(entries: [(date: Date, kg: Double)]) -> Double? {
        guard entries.count >= 2 else { return nil }
        let sorted = entries.sorted { $0.date < $1.date }
        return sorted.last!.kg - sorted.first!.kg
    }

    static func toGoal(current: Double, goal: Double) -> Double {
        current - goal
    }

    /// Number of `stepKg` milestones of loss reached since start. 0 if no loss.
    static func milestonesReached(startKg: Double, currentKg: Double, stepKg: Double) -> Int {
        let loss = startKg - currentKg
        guard loss > 0, stepKg > 0 else { return 0 }
        return Int(loss / stepKg)
    }
}
