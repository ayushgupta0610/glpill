import Foundation

/// Optional Today sections rendered below the pinned ritual + morning-sequence cards.
enum TodaySection: Equatable, Hashable {
    case weightShortcut
    case reportShortcut
    case sideEffects
    case medLevel
    case streak
    case intake
}

enum TodayLayout {
    /// Ordered optional sections below the pinned ritual+sequence. Goal-driven items float up.
    static func sections(goals: [String]) -> [TodaySection] {
        var out: [TodaySection] = []
        if goals.contains("weight") { out.append(.weightShortcut) }
        if goals.contains("doctor") { out.append(.reportShortcut) }
        if goals.contains("sideEffects") { out.append(.sideEffects) }
        for s in [TodaySection.medLevel, .streak, .intake, .sideEffects] where !out.contains(s) { out.append(s) }
        return out
    }
}
