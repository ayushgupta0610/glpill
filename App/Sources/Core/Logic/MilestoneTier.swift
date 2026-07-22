import SwiftUI

/// Pure tier mapping for milestone celebrations: emoji, accent ring color, and
/// confetti particle count scale up as the streak reaches higher thresholds.
enum MilestoneTier {
    static func emoji(for milestone: Int) -> String {
        switch milestone {
        case ..<30: return "🌱"
        case ..<100: return "🔥"
        case ..<365: return "🏆"
        default: return "👑"
        }
    }

    static func ringColor(for milestone: Int) -> Color {
        switch milestone {
        case ..<30: return .green
        case ..<100: return .orange
        case ..<365: return Color(red: 0.83, green: 0.68, blue: 0.21)
        default: return Color(red: 1.0, green: 0.84, blue: 0.0)
        }
    }

    static func particleCount(for milestone: Int) -> Int {
        switch milestone {
        case ..<30: return 24
        case ..<100: return 40
        case ..<365: return 70
        default: return 120
        }
    }
}
