# GLPill v1.0 — Pill-Native Ritual Upgrade

**Date:** 2026-07-19
**Status:** Approved design → implementation plan next

## Goal

Reposition GLPill from "a GLP-1 tracker" (app #7 in a crowded, injection-first category) into **"the app built for the GLP-1 pill"** by making the daily pill *ritual* the hero of the experience — without a rebuild, and without crossing from timing/education into medical advice.

## Why (the wedge)

Every incumbent (Shotsy, MeAgain, Pep, GLP AI, MyTherapy) is injection-first and bolted "log your pill" on as one more row. The oral wave is months old (oral Wegovy Jan 2026, Foundayo/orforglipron Apr 2026). Oral semaglutide has a genuinely hard, underserved problem: the empty-stomach ritual (plain water, then a 30-minute wait before food, drink, or **other oral meds** — thyroid/BP/birth-control timing conflicts are real). Orforglipron has none of those restrictions. Owning that contrast is the wedge; the ritual is the core loop, not a feature.

## Non-goals (explicitly out of v1.0)

- **Per-drug interaction warnings / "what can I take with X" logic** — never, given the neutral-helper decision below. This is medical advice; it would force a repositioning, App Review scrutiny, liability, and an age-rating change.
- **Full "ritual coach"** (hydration nudges, took-it-too-early recovery flow) → v1.1.
- **Clinic / white-label distribution** → separate motion.
- **SEO/content + video engine upgrade** → separate spec (B), authored immediately after this one.

## Constraints

- Preserve the "**tracking tool, not medical advice**" posture end-to-end (App Store description, privacy, **12+ age rating**). The timing helper is neutral, source-cited, and based only on the user's own inputs.
- No rebuild: evolve `TodayView`, reuse `EatTimerView`, `TodayStore`, `Medication.requiresEmptyStomach`, and the existing eat-timer notification.
- Private-by-design unchanged: **Data Not Collected**, local + private CloudKit, no new network calls, no analytics.
- Existing 57 tests stay green; new behavior is test-first (TDD).

---

## Architecture

The change is a **restructure of one card plus a small optional data field**, not new infrastructure.

- Extract the Today tab's top "dose card" into a dedicated `RitualCard` component driven by a pure, derived **state enum** (no new persistence for state — it's computed from existing signals).
- Add one optional user field (`morningMeds: [String]` on `UserSettings`) captured in onboarding and Settings.
- Thread the meds list into the ritual card's "clear" state and the existing window-end notification.
- Everything else on the Today tab (streak, protein/water, side-effects) is unchanged and stays below the ritual card.

### Ritual state (derived, not stored)

```
enum RitualState: Equatable {
    case notTaken(requiresEmptyStomach: Bool)          // no dose logged today
    case windowRunning(end: Date, meds: [String])      // taken, empty-stomach timer active
    case clear(meds: [String], hadWindow: Bool)        // taken + (window elapsed OR no window)
}
```

Derivation (in a small pure function `RitualState.make(...)` — unit-testable, no SwiftUI):

| Signals | State |
|---|---|
| no dose logged today | `.notTaken(requiresEmptyStomach)` |
| dose logged today, `requiresEmptyStomach`, `now < windowEnd` | `.windowRunning(end, meds)` |
| dose logged today, `requiresEmptyStomach`, `now ≥ windowEnd` | `.clear(meds, hadWindow: true)` |
| dose logged today, `!requiresEmptyStomach` | `.clear(meds, hadWindow: false)` |

Inputs: `todayLog != nil`, `medication.requiresEmptyStomach`, `eatTimerEnd`, `now`, `settings.morningMeds`. All already available in `TodayView`.

---

## Components

### 1 · `RitualCard` (new) — `App/Sources/Features/Today/RitualCard.swift`

Renders each `RitualState`:

- **`.notTaken`**: primary `PillCTAButton("Take today's pill")` (existing). Subline:
  - `requiresEmptyStomach == true` → "Empty stomach · plain water · then wait 30 min"
  - `requiresEmptyStomach == false` → "No timing rules — take it with or without food"
  - An `ⓘ` info affordance opens the explainer sheet (section 2).
- **`.windowRunning`**: the countdown is the hero — `RitualCard` **embeds the existing `EatTimerView`** (which keeps its `TimelineView` countdown) at card-level prominence. Below the timer, if `meds` non-empty: "Other morning meds — after \(end formatted)" in secondary style.
- **`.clear`**:
  - `hadWindow == true` → "You're clear ✓ — you can eat now" ; if `meds` non-empty: "You can take your \(meds joined) now."
  - `hadWindow == false` (orforglipron) → "Logged ✓ — no empty-stomach window" ; if `meds` non-empty: "You can take your \(meds joined) any time."

`RitualCard` takes the `RitualState` + a `takePill` closure; it owns no state. `TodayView` computes the state and passes it in. `EatTimerView` is no longer rendered as a *separate top-level card* in `TodayView` — it is now embedded inside `RitualCard`'s `.windowRunning` state, so the timer lives in one place.

### 2 · Morning-meds timing helper

- **Data:** add `morningMeds: [String] = []` to `UserSettings` (`App/Sources/Core/Models/UserSettings.swift`). Names only; no dosages, no times, no interaction data.
- **Capture:** a new optional onboarding sub-step (skippable) — "Other meds you take in the morning?" free-text add/remove list — and an editable section in `SettingsView`.
- **Surfacing:** the ritual card `.clear`/`.windowRunning` states (above) + the existing window-end local notification body, updated to append "You can take your \(meds) now" when `morningMeds` is non-empty.
- **Explainer sheet** (new) — `App/Sources/Features/Today/RitualExplainerView.swift`: a neutral, source-cited "Why the 30-minute window?" sheet reached from the `ⓘ` on the ritual card. Content paraphrases the Rybelsus DailyMed label (empty stomach, plain water, 30-min wait before food/drink/other oral meds) with a "Source: FDA label (DailyMed)" citation. **No advice, no per-drug claims.** Always available via the info button (not force-shown).

### 3 · First-run + input robustness

- **Baseline-weight UX:** `ProgressScreen` empty-state (fewer than 2 entries) shows a clear "Add your starting weight to track progress" card with an "Add weight" button (replaces the bare "—"/"Log at least two weigh-ins" thinness). In onboarding, if weight is left blank, show a one-line note that progress tracking needs a starting weight (still skippable). Validation already exists (25–500 kg / 55–1100 lb), so no `0` can be stored — this is purely the empty-baseline experience.
- **Input sweep:** audit and harden every numeric input for empty / zero / out-of-range with inline errors:
  - Weight & goal (onboarding + `WeightEntrySheet`) — already validated; add tests.
  - Dose steps (`TitrationEditor`) — already clamped 0.05–50 mg; add tests.
  - Protein / water (`IntakeCountersView`) — verify bounds (reject ≤ 0 and absurd values); add validation + tests where missing.

### 4 · Messaging streamline (app-side)

- **Positioning line:** "The app built for the GLP-1 pill."
- **`PaywallView` reframe:** hero headline → "Never mistime your pill again"; reorder bullets to lead with the ritual timer + morning-meds helper + "private by design"; drop generic-tracker phrasing.
- **Onboarding intro copy** aligned to the ritual positioning.
- App Store subtitle/description/keywords already close — minor ASC tweak at submit (not code). Marketing-site copy is handled in spec (B).

### 5 · Pricing: 7-day trial on monthly

- Add a 7-day free-trial `introductoryOffer` (`paymentMode: free`, `subscriptionPeriod: P7D`) to `glpill.pro.monthly` in `App/Resources/GLPill.storekit`, mirroring the yearly plan.
- Paywall copy: both plans show "7-day free trial."
- **Manual step (documented, not code):** configure the same 7-day intro offer on `glpill.pro.monthly` in App Store Connect before submitting.

---

## Data flow

1. `TodayView` reads `todayLog`, `medication.requiresEmptyStomach`, `eatTimerEnd`, `settings.morningMeds`, `now` → `RitualState.make(...)` → passes state to `RitualCard`.
2. `takePill()` (existing) logs the dose; if `requiresEmptyStomach`, sets `eatTimerEnd` and schedules the window-end notification (existing) — now with the meds-aware body.
3. On the next render tick (`TimelineView`, already used by the timer), the state advances `windowRunning → clear` automatically at `windowEnd`.
4. `morningMeds` is set in onboarding/Settings and stored on `UserSettings` (syncs via existing private CloudKit; still Data Not Collected).

## Error handling

- Reuse `TodayView`'s existing `withErrorHandling` for dose logging.
- Morning-meds edits are trivial string-list mutations; guard against empty/whitespace names (trim, drop blanks).
- All numeric inputs fail with clear inline messages (section 3); no silent coercion to 0.

## Testing (TDD)

- **`RitualState.make(...)`** — parameterized unit tests for all four rows of the derivation table (Rybelsus not-taken / running / clear; orforglipron clear-no-window), including the `now == windowEnd` boundary.
- **Notification body** — includes the meds list when `morningMeds` non-empty; omits cleanly when empty.
- **Morning-meds model** — add/remove/trim/dedupe; persists on `UserSettings`.
- **Input boundaries** — parameterized tests for weight, goal, dose, protein, water (empty, 0, negative, over-max, valid).
- **Regression** — existing 57 tests stay green.

## Files touched

- **New:** `App/Sources/Features/Today/RitualCard.swift`, `App/Sources/Features/Today/RitualState.swift`, `App/Sources/Features/Today/RitualExplainerView.swift`
- **Modified:** `TodayView.swift` (use RitualCard; remove inline EatTimerView usage), `UserSettings.swift` (+`morningMeds`), `OnboardingFlow.swift` / `OnboardingStore.swift` (meds step + weight note), `SettingsView.swift` (edit meds), `ProgressScreen.swift` (baseline empty-state), `IntakeCountersView.swift` (bounds), `PaywallView.swift` (messaging), `ReminderScheduler` (meds-aware notification body), `App/Resources/GLPill.storekit` (monthly intro offer)
- **Docs:** `docs/APP_STORE.md` (note monthly 7-day intro-offer ASC step)

## Success criteria

- Opening the app on a pill day makes the *ritual* the obvious primary action; a Rybelsus user sees the countdown as the hero and, at window end, a clear "you can take your other morning meds now" with their list.
- An orforglipron user sees the no-restriction framing (no timer), reinforcing the contrast.
- No numeric input accepts empty/0/out-of-range silently; a new user without a starting weight is nudged rather than shown a broken "—".
- Both subscription plans offer a 7-day free trial.
- Posture unchanged: Data Not Collected, 12+, no advice.
