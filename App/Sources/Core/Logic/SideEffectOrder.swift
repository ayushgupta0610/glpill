import Foundation

enum SideEffectOrder {
    static func kindFor(concern: String) -> SideEffectKind? {
        switch concern {
        case "nausea": return .nausea
        case "constipation": return .constipation
        case "lowAppetite": return .appetiteLoss
        case "fatigue": return .fatigue
        case "reflux": return .reflux
        default: return nil // none / unknown → nil
        }
    }

    /// User's concerns first (in concern order, de-duplicated), then the remaining kinds in natural order.
    static func ordered(concerns: [String]) -> [SideEffectKind] {
        let front = concerns.compactMap(kindFor).reduce(into: [SideEffectKind]()) { if !$0.contains($1) { $0.append($1) } }
        return front + SideEffectKind.allCases.filter { !front.contains($0) }
    }
}
