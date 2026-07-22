# GLPill bug-hunt Round 1 — findings (3 adversarial lenses)

Beyond the already-fixed pre-TestFlight audit. Confirmed, code-reasoned.

## Data integrity
- **DI1 (HIGH):** `ModelMaintenance.deduplicate` keys on `startDate` (mutable — `complete()` sets `startDate = now` on re-onboard) and blind-`delete`s non-kept rows. On a two-device merge it can keep the wrong row (resetting plan/streak/med-level) or delete the row currently being edited → **data loss**. Fix: add immutable `UserSettings.createdAt`; canonical = earliest `createdAt`; dedup MERGES user fields into the kept row before deleting; never key on `startDate`.
- **DI2 (HIGH):** 5 `UserSettings` readers unsorted (`SideEffectSheet`, `MilestoneCelebrationView`, `RecapView`, `MorningMedsEditor`, `WeightEntrySheet.persist` fetch) → bind to a non-canonical row during a merge window. Fix: all read the earliest-`createdAt` row (sorted query / shared helper).
- **DI3 (HIGH):** `complete()` re-onboard overwrites `startDate`/clobbers the canonical row. Fix: upsert into earliest-`createdAt` row, preserve `createdAt`; don't reset `startDate` if already set (or keep the earliest).
- **DI4 (MED-HIGH):** `TodayStore.intakeDay(for:)` (`$0.date == day`) and `logDose` dup-check use exact `Date ==` (timezone/DST-dependent) while views use `isDateInToday`/`isSameDay` → phantom duplicate `IntakeDay` for "today" / lost intake. Fix: `calendar.isDate($0.date, inSameDayAs: date)`.
- **DI5 (HIGH):** `TodayStore.logDose` 6h `takenAt` guard blocks a legit next-**calendar-day** dose taken <6h later (11pm→3am). Fix: dedup on calendar day only (`$0.date == day`), or gate the short window to same-day.
- **DI6 (MED):** silent `try? context.save()` on real writes — `ProgressScreen.deleteEntry`, `TodayView.celebrateMilestoneIfReached` (persists `lastCelebratedMilestone`), `dismissCoaching`, `RecapView` firstName. Fix: `do/catch` + surface/revert (at least deleteEntry + milestone).

## Interaction / UI
- **UX1 (HIGH):** milestone celebration dropped when the pill is logged via the FAB Log sheet — `activeSheet=nil` (dismiss) and `celebratingMilestone=value` (present) in the same tick → present-while-dismiss → milestone silently consumed forever (`lastCelebratedMilestone` bumped, never re-fires). Fix: defer the present (`DispatchQueue.main.async`) or gate on `activeSheet == nil`.
- **UX2 (MED):** `SettingsView` time-picker `.onChange` reschedules the daily reminder without checking `reminderStyle` → setting "Off" then nudging the time resurrects the reminder. Fix: guard `reminderStyle != "none"` inside the time task.
- **UX3 (MED):** nested `NavigationStack` — `WeightShortcutCard`/`ReportShortcutCard` push `ProgressScreen`/`ReportScreen`, which embed their own `NavigationStack` → double nav bar/broken toolbar. Fix: switch to the Progress/Report tab (shared selection) instead of pushing a self-stacked screen.
- **UX4 (MED):** double-tap "Save" duplicates a weigh-in (`WeightEntrySheet.persist` new-entry) and side-effect (`SideEffectSheet`). Fix: a `saving` guard.
- **PK1 (MED):** med-level projection uses `doseLogs.last?.doseMg` (array order, not date) → stale after out-of-order CloudKit sync. Fix: use `store.currentDoseMg()`. Also cap the curve lookback (fixed 40 samples over a huge span under-samples).
- **LOC1 (LOW):** `ReportComposer` `date.formatted(...)` emits localized digits in the clinician report (mixed numerals). Fix: `en_US_POSIX`.
- **COS1 (LOW):** stale `eatTimerEnd` renders "After 8:14 AM" for a window that closed (until relaunch). Same-day guard.
- **COS2 (LOW):** rapid double quick-add water/protein leaves only the last undoable. (defer)
- **COS3 (LOW):** today's dose contributes to only the final curve sample (visual step vs "steady" caption). (defer)
