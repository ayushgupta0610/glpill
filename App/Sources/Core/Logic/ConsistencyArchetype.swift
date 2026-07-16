import Foundation

/// The identity layer of the monthly recap. We celebrate *character* ("you are
/// this kind of person"), never the medication or the scale — this is what makes
/// the card shareable pride rather than a disclosure of being on a GLP-1.
enum ConsistencyArchetype: String, CaseIterable {
    case justStarting
    case comebackKid
    case quietMachine
    case onARoll
    case steadyOne

    var title: String {
        switch self {
        case .justStarting: return "Just Getting Started"
        case .comebackKid:  return "The Comeback Kid"
        case .quietMachine: return "The Quiet Machine"
        case .onARoll:      return "On a Roll"
        case .steadyOne:    return "The Steady One"
        }
    }

    var subtitle: String {
        switch self {
        case .justStarting: return "Every streak starts with day one."
        case .comebackKid:  return "You missed a day — and came right back."
        case .quietMachine: return "Almost flawless. Nearly every single day."
        case .onARoll:      return "Your best streak yet."
        case .steadyOne:    return "Consistent, quietly unstoppable."
        }
    }

    var emoji: String {
        switch self {
        case .justStarting: return "🌱"
        case .comebackKid:  return "💪"
        case .quietMachine: return "⭐️"
        case .onARoll:      return "🔥"
        case .steadyOne:    return "🧭"
        }
    }

    /// Picks the archetype from the month's signals. Order is priority:
    /// too-little-data first, then flawless, then a personal best, then a
    /// recovery, else steady.
    static func select(
        daysLogged: Int,
        consistencyPercent: Int,
        isAllTimeBest: Bool,
        hadComeback: Bool
    ) -> ConsistencyArchetype {
        if daysLogged < 5 { return .justStarting }
        if consistencyPercent >= 95 { return .quietMachine }
        if isAllTimeBest { return .onARoll }
        if hadComeback { return .comebackKid }
        return .steadyOne
    }
}
