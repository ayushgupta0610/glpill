import Foundation
import SwiftData

/// Launch-time cleanup for singleton-ish models that CloudKit sync can duplicate
/// across devices. `UserSettings` and `Medication` are conceptually one-per-user;
/// if two devices both created a row before syncing, we keep the earliest
/// (`createdAt`) row, MERGE the extras' user-meaningful fields into it, then delete
/// the extras. Merging (rather than blind-deleting) guarantees no user data is lost
/// regardless of which device's row happens to win the merge.
enum ModelMaintenance {
    /// Collapses duplicate `UserSettings` and `Medication` down to the single
    /// earliest-`createdAt` row of each, merging complementary fields first. Safe to
    /// call on every launch; a no-op when there's 0 or 1 of each.
    static func deduplicate(in context: ModelContext) {
        collapseUserSettings(
            context.fetchSorted(FetchDescriptor<UserSettings>()) { $0.createdAt < $1.createdAt },
            in: context
        )
        collapseMedication(
            context.fetchSorted(FetchDescriptor<Medication>()) { $0.createdAt < $1.createdAt },
            in: context
        )
        if context.hasChanges { try? context.save() }
    }

    private static func collapseUserSettings(_ sorted: [UserSettings], in context: ModelContext) {
        guard let keep = sorted.first, sorted.count > 1 else { return }
        for extra in sorted.dropFirst() {
            merge(extra, into: keep)
            context.delete(extra)
        }
    }

    /// Merges `extra` into the canonical `keep` row without ever clobbering a real
    /// value on `keep`. `keep` is the earliest-`createdAt` row and WINS for every
    /// scalar preference — those are never taken from `extra`, since a genuine value
    /// on `keep` can coincide with the model default (e.g. `reminderStyle == "full"`,
    /// 9:00 AM, default targets) and must not be silently reset to `extra`'s value.
    /// Only fields that carry an explicit "unset" signal (nil / empty collection) are
    /// filled from `extra`, and only when `keep` is truly unset.
    private static func merge(_ extra: UserSettings, into keep: UserSettings) {
        // Scalar preferences: canonical `keep` always wins — never merged.

        // Nil-signalled fields: fill only when `keep` is still unset.
        if keep.firstName == nil { keep.firstName = extra.firstName }
        if keep.goalKilograms == nil { keep.goalKilograms = extra.goalKilograms }
        if keep.startKilograms == nil { keep.startKilograms = extra.startKilograms }
        if keep.onboardingStage == nil { keep.onboardingStage = extra.onboardingStage }
        // Empty-signalled collections: fill only when `keep` is still empty.
        if keep.morningMeds.isEmpty { keep.morningMeds = extra.morningMeds }
        if keep.sideEffectConcerns.isEmpty { keep.sideEffectConcerns = extra.sideEffectConcerns }
        if keep.goals.isEmpty { keep.goals = extra.goals }
        // Completion is a one-way latch: complete on either row wins.
        keep.onboardingComplete = keep.onboardingComplete || extra.onboardingComplete
    }

    private static func collapseMedication(_ sorted: [Medication], in context: ModelContext) {
        guard let keep = sorted.first, sorted.count > 1 else { return }
        for extra in sorted.dropFirst() {
            merge(extra, into: keep)
            context.delete(extra)
        }
    }

    /// Canonical `keep` wins for the medication's own fields (kind, empty-stomach);
    /// only the nil-signalled `customName` is filled from `extra` when `keep` lacks one.
    private static func merge(_ extra: Medication, into keep: Medication) {
        if keep.customName == nil { keep.customName = extra.customName }
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
