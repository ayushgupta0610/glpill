import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The small, Codable slice of state the widget needs. Written by the app into
/// the shared App Group, read by the widget extension. Deliberately tiny — the
/// widget never touches SwiftData or CloudKit.
struct GLPillWidgetSnapshot: Codable, Equatable {
    var streak: Int
    var doseTakenToday: Bool
    var medShortName: String
    var doseMg: Double

    static let placeholder = GLPillWidgetSnapshot(streak: 7, doseTakenToday: true, medShortName: "Rybelsus", doseMg: 7)
    static let empty = GLPillWidgetSnapshot(streak: 0, doseTakenToday: false, medShortName: "GLP-1 pill", doseMg: 0)
}

/// Bridges the app and the widget via a shared App Group container.
enum GLPillWidgetBridge {
    static let appGroupID = "group.com.ayushgupta.glpill"
    static let snapshotKey = "widgetSnapshot"

    static func save(_ snapshot: GLPillWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
        reload()
    }

    static func load() -> GLPillWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(GLPillWidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func reload() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
