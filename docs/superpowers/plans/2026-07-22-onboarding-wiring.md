# GLPill — Wire Up Onboarding Answers

> Make the onboarding promises real. Branch `feat/onboarding-wiring` (worktree, off main). TDD for logic; views get build verification. Constraints intact: **timing/education only — NO medical advice**, non-shaming, Data Not Collected.

**Problem:** `UserSettings.goals`, `sideEffectConcerns`, `onboardingStage` are collected in onboarding but never read; `reminderStyle`'s "full" vs "pill only" is currently identical in effect. This pass wires all four so the answers change the app.

**Conventions:** run from the worktree root; `xcodegen generate` there after NEW files; build/test `xcodebuild -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`; use `-only-testing:` (the known `StoreKitConfigTests.testPurchaseYearlyUnlocksEntitlement` headless crash hangs a full run — ignore it). Swift Testing for new tests. Commit per group; no attribution footer.

**Known ids:**
- goals: `pillDaily, consistency, sideEffects, doctor, weight`
- concerns: `nausea, constipation, lowAppetite, fatigue, reflux, none`
- `SideEffectKind`: `nausea, vomiting, constipation, diarrhea, fatigue, headache, appetiteLoss, other`
- Today section order today: ritualCard → (MorningSequenceCard) → MedLevelPreviewCard → streakCard → IntakeCountersView → sideEffectCard.

---

## GROUP 1 — Goals → Today emphasis + Concerns → side-effect ordering

**Files:** new `App/Sources/Core/Logic/TodayLayout.swift` (pure, TDD); new `App/Sources/Features/Today/WeightShortcutCard.swift` + `ReportShortcutCard.swift`; `App/Sources/Features/Today/TodayView.swift`; new `App/Sources/Core/Logic/SideEffectOrder.swift` (pure, TDD); `App/Sources/Features/Today/SideEffectSheet.swift`; `App/Sources/Features/Onboarding/Steps/ConcernsStep.swift` (copy).

### 1a. Goals → ordered Today sections
`ritualCard` and the morning-sequence card stay PINNED at top (core ritual). Everything below is ordered by goals.
```swift
enum TodaySection: Equatable { case weightShortcut, reportShortcut, sideEffects, medLevel, streak, intake }

enum TodayLayout {
    /// Ordered optional sections below the pinned ritual+sequence. Goal-driven items float up.
    static func sections(goals: [String]) -> [TodaySection] {
        var out: [TodaySection] = []
        if goals.contains("weight") { out.append(.weightShortcut) }
        if goals.contains("doctor") { out.append(.reportShortcut) }
        if goals.contains("sideEffects") { out.append(.sideEffects) }
        for s in [TodaySection.medLevel, .streak, .intake, .sideEffects] where !out.contains(s) { out.append(s) }
        return out
    }
}
```
Test `TodayLayoutTests`: empty goals → `[.medLevel,.streak,.intake,.sideEffects]`; `["sideEffects"]` → sideEffects first; `["weight","doctor"]` → weightShortcut,reportShortcut lead; no duplicate `.sideEffects`.

In `TodayView`: render `ritualCard`, the sequence card, then `ForEach(TodayLayout.sections(goals: settingsList.first?.goals ?? []))` switching each case to the right view. New small cards:
- **`WeightShortcutCard`** — compact: latest weight (from a `@Query WeightEntry` or passed in) + "See your trend" → `NavigationLink`/tab intent to Progress. If no weight yet, "Log your first weigh-in". Keep it calm, no goal-weight shaming.
- **`ReportShortcutCard`** — "Doctor-ready report" + one line ("Adherence, doses & side effects") → opens the Report tab/screen.
Keep `.medLevel`→`MedLevelPreviewCard`, `.streak`→`streakCard`, `.intake`→`IntakeCountersView`, `.sideEffects`→`sideEffectCard` (existing views).

### 1b. Concerns → side-effect quick-log ordering
```swift
enum SideEffectOrder {
    static func kindFor(concern: String) -> SideEffectKind? {
        switch concern { case "nausea": return .nausea; case "constipation": return .constipation
        case "lowAppetite": return .appetiteLoss; case "fatigue": return .fatigue; default: return nil } // reflux/none → nil
    }
    /// User's concerns first (in concern order), then the remaining kinds in natural order.
    static func ordered(concerns: [String]) -> [SideEffectKind] {
        let front = concerns.compactMap(kindFor).reduce(into: [SideEffectKind]()) { if !$0.contains($1) { $0.append($1) } }
        return front + SideEffectKind.allCases.filter { !front.contains($0) }
    }
}
```
Test `SideEffectOrderTests`: `["constipation","nausea"]` → constipation, nausea first; unknown/"reflux"/"none" ignored; result contains every kind exactly once.
In `SideEffectSheet`: order the kind list via `SideEffectOrder.ordered(concerns: settingsList.first?.sideEffectConcerns ?? [])` (add a `@Query settingsList` if not present) instead of `SideEffectKind.allCases`.

### 1c. Honest copy
In `ConcernsStep.swift`, change the subtitle from "We'll tailor gentle tips and make these one-tap to log." to **"We'll put these first when you log how you feel."** (We deliberately do NOT add symptom "tips" — that edges into medical advice, which the app must not give.)

Commit: `feat: goals reorder Today + concerns order side-effect log`

---

## GROUP 2 — Stage → first-run coaching + reminderStyle → real effect

**Files:** `App/Sources/Core/Models/UserSettings.swift` (add `coachingDismissed`); new `App/Sources/Core/Logic/StageCoaching.swift` (pure, TDD) + `App/Sources/Features/Today/StageCoachingCard.swift`; `App/Sources/Features/Today/TodayView.swift`; `App/Sources/Features/Settings/SettingsView.swift`.

### 2a. Stage → dismissible coaching card
Add `var coachingDismissed: Bool = false` to `UserSettings` (defaulted, migration-safe; add to init).
```swift
enum StageCoaching {
    /// One-time, stage-tailored orientation. Timing/logging guidance only — no medical advice. nil = no card.
    static func message(stage: String?, requiresEmptyStomach: Bool) -> String? {
        switch stage {
        case "switchingFromInjections":
            return requiresEmptyStomach
              ? "Switching from a shot? The big change: take this pill on an empty stomach, then wait before eating — we'll time it for you."
              : "Switching from a shot? Just take your pill daily and log it — we'll handle reminders."
        case "aboutToStart": return "Starting soon? Log your first pill the moment you take it — we'll handle the timing and reminders."
        case "firstWeeks": return "The first few weeks are when side effects peak — log how you feel so your doctor report stays accurate."
        default: return nil // "aWhile" or unknown → no card
        }
    }
}
```
Test `StageCoachingTests`: switching+emptyStomach vs not differ; aboutToStart/firstWeeks non-nil; "aWhile"/nil → nil.
`StageCoachingCard` — a calm dismissible card (icon + text + an "×"/"Got it"). Shown in `TodayView` (near the top, below ritual) only when `!coachingDismissed` and `StageCoaching.message(...) != nil`; dismiss sets `settings.coachingDismissed = true` + saves.

### 2b. reminderStyle → make "pill only" mean something
In `TodayView.takePill()`, only schedule the window-clear (eat-timer) notification when `reminderStyle == "full"`:
```swift
if startTimer {
    let minutes = settingsList.first?.waitWindowMinutes ?? 30
    eatTimerEnd = ...
    if (settingsList.first?.reminderStyle ?? "full") == "full" {
        ReminderScheduler.scheduleEatTimer(using: UNNotificationScheduler(), meds: settingsList.first?.morningMeds ?? [])
    }
}
```
(The in-app countdown still shows regardless; only the push is gated.)
**Settings toggle:** in `SettingsView`, add a "Reminders" `Picker` bound to the `UserSettings.reminderStyle` (options: full = "Pill + window clear", pillOnly = "Pill only", none = "Off"). On change: persist, and reschedule/cancel the DAILY reminder via `ReminderScheduler` (schedule when != none using the stored reminderHour/minute; cancel when none). Follow the existing Settings pattern for the reminder-time control (there's already reminder scheduling there — mirror it). Keep it simple + correct.

Commit: `feat: stage coaching card + reminderStyle now affects notifications`

---

## Verification
- Targeted suites green: `TodayLayoutTests`, `SideEffectOrderTests`, `StageCoachingTests`, `UserSettingsTests` (coachingDismissed default).
- Build SUCCEEDED; re-run `QAWalkthroughTests` (onboarding→Today) as regression.
