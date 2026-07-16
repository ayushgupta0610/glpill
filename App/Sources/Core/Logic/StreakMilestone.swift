import Foundation

/// Streak thresholds that trigger a shareable Trophy Card celebration.
enum StreakMilestone {
    static let thresholds = [7, 30, 100, 365]

    /// The milestone to celebrate right now: the highest threshold the current
    /// streak has reached that hasn't been celebrated yet. `nil` if none.
    /// `lastCelebrated` is persisted so a milestone fires once, not every launch.
    static func newlyReached(streak: Int, lastCelebrated: Int) -> Int? {
        thresholds
            .filter { $0 <= streak && $0 > lastCelebrated }
            .max()
    }

    /// Warm, non-clinical celebration copy for a reached milestone.
    static func headline(for milestone: Int) -> String {
        switch milestone {
        case 7:   return "One week. Not one missed."
        case 30:  return "30 days. You showed up every time."
        case 100: return "100 days. That's not luck — that's you."
        case 365: return "A full year. Quietly unstoppable."
        default:  return "\(milestone) days strong."
        }
    }
}
