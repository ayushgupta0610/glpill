import Foundation
import SwiftData

enum SideEffectKind: String, Codable, CaseIterable {
    case nausea
    case vomiting
    case constipation
    case diarrhea
    case fatigue
    case headache
    case appetiteLoss
    case reflux
    case other

    var label: String {
        switch self {
        case .nausea: return "Nausea"
        case .vomiting: return "Vomiting"
        case .constipation: return "Constipation"
        case .diarrhea: return "Diarrhea"
        case .fatigue: return "Fatigue"
        case .headache: return "Headache"
        case .appetiteLoss: return "Appetite loss"
        case .reflux: return "Reflux / burping"
        case .other: return "Other"
        }
    }

    var emoji: String {
        switch self {
        case .nausea: return "🤢"
        case .vomiting: return "🤮"
        case .constipation: return "🪨"
        case .diarrhea: return "💧"
        case .fatigue: return "😴"
        case .headache: return "🤕"
        case .appetiteLoss: return "🍽️"
        case .reflux: return "😮‍💨"
        case .other: return "📝"
        }
    }
}

@Model
final class SideEffectLog {
    var date: Date = Date.now
    var kindRaw: String = SideEffectKind.other.rawValue
    /// 1 = mild, 2 = moderate, 3 = severe
    var severity: Int = 1
    var note: String?

    init(date: Date, kind: SideEffectKind, severity: Int, note: String? = nil) {
        self.date = date
        self.kindRaw = kind.rawValue
        self.severity = min(max(severity, 1), 3)
        self.note = note
    }

    var kind: SideEffectKind {
        SideEffectKind(rawValue: kindRaw) ?? .other
    }
}
