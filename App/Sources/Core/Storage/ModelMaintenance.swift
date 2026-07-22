import Foundation
import SwiftData

/// Launch-time cleanup for singleton-ish models that CloudKit sync can duplicate
/// across devices. `UserSettings` and `Medication` are conceptually one-per-user;
/// if two devices both created a row before syncing, we keep the earliest and
/// delete the rest so downstream `.first` reads are deterministic.
enum ModelMaintenance {
    /// Collapses duplicate `UserSettings` (by `startDate`) and `Medication`
    /// (by `createdAt`) down to the single earliest row of each. Safe to call on
    /// every launch; a no-op when there's 0 or 1 of each.
    static func deduplicate(in context: ModelContext) {
        collapse(
            context.fetchSorted(FetchDescriptor<UserSettings>()) { $0.startDate < $1.startDate },
            in: context
        )
        collapse(
            context.fetchSorted(FetchDescriptor<Medication>()) { $0.createdAt < $1.createdAt },
            in: context
        )
        if context.hasChanges { try? context.save() }
    }

    private static func collapse<T: PersistentModel>(_ sorted: [T], in context: ModelContext) {
        guard sorted.count > 1 else { return }
        for extra in sorted.dropFirst() {
            context.delete(extra)
        }
    }
}

private extension ModelContext {
    func fetchSorted<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        by areInIncreasingOrder: (T, T) -> Bool
    ) -> [T] {
        ((try? fetch(descriptor)) ?? []).sorted(by: areInIncreasingOrder)
    }
}
