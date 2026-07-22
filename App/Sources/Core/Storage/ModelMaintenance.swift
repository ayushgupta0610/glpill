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

    /// Fills each of `keep`'s user-meaningful fields from `extra` only when `keep`'s
    /// value is still default/empty, so the union of both rows survives.
    private static func merge(_ extra: UserSettings, into keep: UserSettings) {
        if keep.firstName == nil { keep.firstName = extra.firstName }
        if keep.goalKilograms == nil { keep.goalKilograms = extra.goalKilograms }
        if keep.startKilograms == nil { keep.startKilograms = extra.startKilograms }
        if !keep.usesMetric { keep.usesMetric = extra.usesMetric }
        if keep.reminderHour == 9 { keep.reminderHour = extra.reminderHour }
        if keep.reminderMinute == 0 { keep.reminderMinute = extra.reminderMinute }
        if keep.proteinTargetGrams == 100 { keep.proteinTargetGrams = extra.proteinTargetGrams }
        if keep.waterTargetMl == 2000 { keep.waterTargetMl = extra.waterTargetMl }
        if keep.morningMeds.isEmpty { keep.morningMeds = extra.morningMeds }
        if keep.onboardingStage == nil { keep.onboardingStage = extra.onboardingStage }
        if keep.sideEffectConcerns.isEmpty { keep.sideEffectConcerns = extra.sideEffectConcerns }
        if keep.goals.isEmpty { keep.goals = extra.goals }
        if keep.reminderStyle == "full" { keep.reminderStyle = extra.reminderStyle }
        if !keep.coachingDismissed { keep.coachingDismissed = extra.coachingDismissed }
        keep.onboardingComplete = keep.onboardingComplete || extra.onboardingComplete
    }

    private static func collapseMedication(_ sorted: [Medication], in context: ModelContext) {
        guard let keep = sorted.first, sorted.count > 1 else { return }
        for extra in sorted.dropFirst() {
            merge(extra, into: keep)
            context.delete(extra)
        }
    }

    /// Medication has far fewer fields; fill the kept row only where it's still on
    /// the model default (custom kind / no custom name).
    private static func merge(_ extra: Medication, into keep: Medication) {
        if keep.kind == .custom { keep.kindRaw = extra.kindRaw }
        if keep.customName == nil { keep.customName = extra.customName }
        if !keep.requiresEmptyStomach { keep.requiresEmptyStomach = extra.requiresEmptyStomach }
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
