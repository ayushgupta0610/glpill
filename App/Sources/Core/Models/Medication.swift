import Foundation
import SwiftData

enum MedicationKind: String, Codable, CaseIterable {
    case foundayo
    case rybelsus
    case custom

    var defaultDisplayName: String {
        switch self {
        case .foundayo: return "Foundayo (orforglipron)"
        case .rybelsus: return "Rybelsus (semaglutide)"
        case .custom: return "Custom medication"
        }
    }

    var defaultRequiresEmptyStomach: Bool {
        self == .rybelsus
    }
}

@Model
final class Medication {
    var kindRaw: String = MedicationKind.custom.rawValue
    var customName: String?
    var requiresEmptyStomach: Bool = false
    var createdAt: Date = Date.now

    init(kind: MedicationKind, customName: String? = nil, createdAt: Date = .now) {
        self.kindRaw = kind.rawValue
        self.customName = customName
        self.requiresEmptyStomach = kind.defaultRequiresEmptyStomach
        self.createdAt = createdAt
    }

    var kind: MedicationKind {
        MedicationKind(rawValue: kindRaw) ?? .custom
    }

    var displayName: String {
        if let customName, !customName.isEmpty { return customName }
        return kind.defaultDisplayName
    }
}
