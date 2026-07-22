# GLPill pre-TestFlight edge-case audit — 2026-07-22

Coverage: all 19 feature areas (5 parallel deep-audit agents). Migration = SAFE (all new SwiftData fields defaulted/optional). Freemium security = solid (DEBUG unlock `#if DEBUG`-gated, fails closed).

## CRITICAL
1. **Unknown dose fabricates a flat "0 mg steady-state" curve** · `Core/Logic/MedicationLevel.swift:27-30` (consumer `TodayView.swift:148-150`). 3+ doses over ≥2 days with dose="Not sure" (`doseMg==0`) → curve is all-zeros, `hasEnoughData` true (dates only) → solid line at 0 labeled "steady daily levels." Fabricated medical reading. **Fix:** filter input doses to `mg>0` at the boundary; if none, return `[]`; guard `hasEnoughData` against all-zero.
2. **Eat-timer notification hardcodes 30 min + "30 minutes are up"** · `Core/Notifications/ReminderScheduler.swift:36,30`. In-app timer uses `waitWindowMinutes`, but the notification always fires at 30 min. 60-min user told to eat 30 min early. **Fix:** pass `waitWindowMinutes` into `scheduleEatTimer`; use it for trigger + body.
3. **Upgraded / multi-device users get NO daily reminder (silent)** · `OnboardingFlow.swift:64-80`, `SettingsView.swift`. `scheduleDaily` runs only at onboarding + Settings.onChange; an already-onboarded user never re-asserts it. **Fix:** on launch, if `onboardingComplete && reminderStyle != "none"` && authorized && `glpill.daily` absent from pending → reschedule.

## HIGH
4. **Notification auth denied swallowed — UI says "Reminders on"** · `OnboardingFlow.swift:72`, `SettingsView.swift:67,90`, `PlanRevealStep.swift:26`. **Fix:** capture the `false`; non-blocking banner + deep link; reflect denied in Settings footer.
5. **Report understates adherence + fabricates huge "longest gap" for new users** · `Core/Logic/ReportComposer.swift:36-46` + `AdherenceStats` (no plan-start floor; HistoryView floors, report doesn't). Started 3 days ago → "10% (3 of 30 days), Longest gap: 25 days". **Fix:** clamp window start to `max(windowStart, planStart)` for denominator + gap.
6. **History ignores locale week-start** · `HistoryView.swift:86-87,168-169` (hardcoded S-M-T-W-T-F-S, Sunday-anchored pad). **Fix:** header from `calendar.shortWeekdaySymbols` rotated by `firstWeekday-1`; pad `(weekday-firstWeekday+7)%7`.
7. **Tap-to-type intake crashes on huge/`inf` input** · `IntakeCountersView.swift:91,73,82`. `Int(1e30)`/`Int(.infinity)` traps; oz→ml multiply overflows. **Fix:** `guard value.isFinite, 0...100_000 ~= value`; cap before oz→ml.
8. **Comma-decimal locales can't enter fractional intake (silent no-op)** · `IntakeCountersView.swift:90,72-85`. `Double("2,5")`→nil→"Set" silently no-ops. **Fix:** locale-aware `NumberFormatter`; on failure keep alert open / show error.
9. **Paywall has no visible dismiss** · `PaywallView.swift` (presented at `PremiumGate.swift:19`). App Review 3.1.2 risk. **Fix:** `.toolbar` Close button → `@Environment(\.dismiss)`.
10. **`.first` on UserSettings/Medication non-deterministic under CloudKit dup** · `RootView.swift:9`, `SettingsView.swift:26`, `MedicationEditor.swift:10`, `TodayView.swift:302-307`, `WidgetSnapshotBuilder.swift:29,37`; `OnboardingStore.complete` always inserts a new `UserSettings` (`:77`). **Fix:** `complete()` fetch-and-update existing; stable sort + launch de-dup keeping earliest.

## Also (HIGH/MEDIUM)
- **Onboarding orphaned inserts on validation throw** · `OnboardingStore.swift:63-68` — Medication/TitrationSteps inserted before the dose-validation `throw`, no rollback → retry duplicates. Fix: validate before insert, or `context.rollback()` in catch.
- **Custom med saves fabricated 0.8 mg** · `DoseLadderStep`/`OnboardingStore.swift:33` — `steps` defaults `[0.8mg]`; blank custom entry persists phantom Rybelsus-shaped dose. Fix: default `steps=[]`, require entry.
- **Eat-timer not canceled on reminderStyle change mid-window** · `SettingsView.swift:61-75` only touches `glpill.daily`. Fix: also `removePending([eatTimerId])`.
- **`restore()` false-negative on slow network** · `SubscriptionStore.swift:151-165` — 5s timeout → fails closed → "No active subscription found" for a real subscriber. Fix: distinguish timed-out from provider-locked.
- **Projection plotted in the past** · `TodayView.swift:155-156` — `startingFrom: doseLogs.first?.takenAt` (oldest). Fix: start from `.now`.
- **Report dose line implies false chronology** · `ReportComposer.swift:49-58` — `Set.sorted()` renders 14→7 mg de-escalation as "7 mg → 14 mg". Fix: drop the arrow or order by first appearance.
- **Transaction listener handle discarded** · `GLPillApp.swift:36` `_ = …startTransactionListener()`. Fix: retain the Task on the store.
- **Intake no upper cap** · `TodayStore.swift:53-75` clamps only lower. Fix: sane ceiling.
- **Future-stamped doses in curve** · `MedicationLevel.swift:29`. Fix: clamp `takenAt<=now` / `now=max(.now,maxDose)`.
- **Widget streak stale** · `GLPillWidget.swift:30-52` — streak not invalidated at midnight. Fix: derive at-risk/not-taken state.

## LOW / polish
Dead unknown-dose widget fields; `longestStreak` component-diff vs day-walk; `IntakeDay` exact-`Date==` vs `isDateInToday`; `isValidWeight` rejects genuine 55 lb; Dynamic-Type overflow in stepper row; ProgressView missing VoiceOver label; MedicationEditor stale `customName`; WAL/SHM file-protection race.

## Verified solid — no issue
Freemium security (DEBUG-gated unlock, fail-closed, `ResumeOnce` race correct, foreign product-ID reject) · SwiftData migration · dose honesty on doseSubtitle/report/projection (only historical `curve` fabricates = #1) · share-card export (no confetti; fire-once correct) · RitualState machine · onboarding back/advance symmetry (no double-complete) · History 4-state distinction + planStart floor (aside from week-start) · StreakCalculator/AdherenceStats/MilestoneTier/ModelContainerFactory/ReminderScheduler ids/WeightStats fallback · no in-app delete-all (matches privacy posture).
