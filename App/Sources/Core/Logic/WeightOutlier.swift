import Foundation

/// Pure guard that flags an implausible weigh-in jump so we can ask the user
/// to double-check (usually a kg/lb mix-up) before saving.
enum WeightOutlier {
    /// True when a previous weigh-in exists and the new value differs from it
    /// by more than 25%. A first-ever entry (`lastKg == nil`) is never suspicious.
    static func isSuspicious(newKg: Double, lastKg: Double?) -> Bool {
        guard let lastKg, lastKg > 0 else { return false }
        return abs(newKg - lastKg) / lastKg > 0.25
    }
}
