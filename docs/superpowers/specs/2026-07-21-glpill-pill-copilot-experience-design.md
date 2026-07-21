# GLPill — Pill Co-Pilot Experience (Onboarding + Today + Med-Level Graph + Freemium)

**Date:** 2026-07-21
**Status:** Approved design, ready for implementation plan
**Scope:** Onboarding redesign · Ritual-first Today home · Pill-adapted medication-level graph · Morning-meds sequencing · Freemium model flip
**Prompted by:** Competitor teardown of **MeAgain** (video walkthrough) + a challenge to find a defensible wedge beyond "privacy."

---

## 1. Context & goal

GLPill is a SwiftUI + SwiftData iOS companion for **oral** GLP-1s (Foundayo/orforglipron, Rybelsus, Wegovy pill, compounded oral). v1.0 is built and was ready to submit, then held to ship a stronger pill-native version first.

This session tore down the leading competitor, **MeAgain** (421K users, 4.8★). The goal: make GLPill's experience genuinely solid for anyone who tries it, and re-anchor it on a wedge that survives scrutiny.

Screenshots of the teardown live in `docs/competitor/meagain/`.

## 2. The wedge

Two prior wedges were tested and rejected as insufficient:

- **"Private by design" is table stakes.** MeAgain's onboarding literally says *"Your privacy comes first"*; Shotsy stores on-device via iCloud and "never sells your data." Everyone claims it. It stays as *proof*, never the headline.
- **"The app for GLP-1 pills" is half-closed.** Shotsy, MeAgain, and Pep all now advertise "weekly shots **or** daily pills." The empty-stomach *timer* only helps oral semaglutide (Rybelsus / Wegovy pill); Foundayo has no timing rules.

**The wedge we will build:** *the pill is a different patient and a different daily job.*

- Injection apps are **weekly weight-loss trackers**. A large share of oral-semaglutide users are **Type 2 diabetics and medically complex, multi-medication** people whom the weight-loss-casino framing actively alienates.
- Their real **daily** job is **taking the pill correctly and in the right order alongside their other morning meds** — not "dream weight." No competitor does medication sequencing.
- GLPill owns the **calm, medical, non-shaming daily ritual + morning-meds sequencing**. Incumbents structurally can't follow without gutting their weight-loss funnel and identity (innovator's dilemma). This *extends* the `morningMeds` helper GLPill already shipped rather than discarding it.

Positioning line (existing, retained): *"Every GLP-1 app wants your data. GLPill can't even see it."* — privacy as proof; pill-native ritual + sequencing as the functional wedge.

## 3. Scope

**In scope (this spec):**
1. **Onboarding** — expanded from 6 to ~11 thoughtful, drug-aware steps with researched tappable options.
2. **Today home** — ritual-first layout (Direction A): ritual hero → morning sequence → med-level graph preview → intake counters → side-effect quick-log.
3. **Medication-level graph** — new component, pill-adapted (daily steady-state curve), preview free / full premium.
4. **Morning-meds sequencing** — surfaced on Today as "Your morning sequence" (extends existing `morningMeds`).
5. **Freemium flip** — the whole app becomes usable free; entitlement gates only premium features (replacing the current hard paywall in `RootView`).

**Out of scope (deferred):**
- Redesign of Progress / History / Report / Settings tabs (left as-is; only Today is enriched).
- Nutrition/food logging beyond the existing protein/water intake counters (no calorie/macro database — deliberately not the weight-loss casino).
- AI chat companion (MeAgain's "Capy"). Not our twist.
- Apple Health *write*-back, progress photos, social features.

## 4. Research findings (grounding)

Verified this session (sources are real; captured for the implementer):

- **Rybelsus (oral semaglutide, T2D):** doses 3 → 7 → 14 mg (step ~every 30 days). Empty stomach, ≤4 oz plain water, wait ≥30 min before food/drink/other meds/vitamins. Longer wait (up to ~2h) improves absorption. Real-world fasting compliance ~56% at 6 months.
- **Wegovy pill (oral semaglutide 25 mg, weight mgmt):** FDA-approved Dec 22 2025, launched Jan 2026. Doses 1.5 → 4 → 9 → 25 mg. Same empty-stomach ritual as Rybelsus.
- **Foundayo (orforglipron):** FDA-approved Apr 1 2026. Doses 0.8 → 2.5 → 5.5 → 9 → 14.5 → 17.2 mg. **No food/water/timing restrictions** — any time of day.
- **Levothyroxine interaction:** oral semaglutide raises levothyroxine exposure ~33%; correct sequence is pill on waking → wait → thyroid → wait → food. This is the flagship reason morning-meds sequencing matters (thyroid leads the sequencing list).
- **Side-effect prevalence** (Foundayo label): nausea 26–35%, constipation 20–27% are the top two → they lead the concern list.

**Guardrail:** all medication content is **timing/routine/education only** — no dosing advice, no interaction *claims* in-UI, no per-drug medical recommendations. Preserves the 12+ age rating and the "Data Not Collected" posture. Dose ladders are presented as *"the steps your prescriber gave you,"* pre-fillable from the known ladder but never auto-escalated.

## 5. Design — Onboarding (~11 steps)

Replaces the current 6-step `OnboardingFlow`. Warm and personalized like MeAgain, but **pill-first, honest (no fake loaders, no rating traps), non-shaming, and ends in the app (free)**. Every step is a tappable choice — no free-text where an option set belongs. "Not sure" / "Skip" always available; nothing blocks the user.

| # | Screen | Type | Options / content |
|---|--------|------|-------------------|
| 1 | **Welcome** | value, no Q | 1–2 honest slides. Lead: *"The calm daily co-pilot for the GLP-1 pill."* Sub: take it right, remember your other meds, steady progress — without the weight-loss noise. Optional privacy proof slide. Keep the "not medical advice" disclaimer. |
| 2 | **Stage** | 1-choice | About to start · In my first few weeks · Been on it a while · **Switching from injections** |
| 3 | **Which pill ★** | 1-choice | Foundayo (orforglipron) · Rybelsus (oral semaglutide) · Wegovy pill (oral sema 25mg) · Compounded oral semaglutide · Not sure / haven't decided |
| 4 | **Dose** | 1-choice, drug-aware | Ladder per pill (Rybelsus 3/7/14; Foundayo 0.8/2.5/5.5/9/14.5/17.2; Wegovy 1.5/4/9/25) + "Not sure". Copy: most begin at the lowest dose and step up ~every 30 days. |
| 5 | **Daily time** | chips + picker | As soon as I wake · 7:00 AM · 8:00 AM · Custom. Copy adapts: empty-stomach pills nudge morning; Foundayo says "any time you'll remember." |
| 6 | **Wait window ★** | 1-choice, conditional | *Empty-stomach pills only:* "How long can you wait before breakfast?" → 30 min (minimum) · 45 min · 1 hour · As long as I can (up to 2h). *Foundayo:* reassurance card "No waiting needed" + Got it. |
| 7 | **Morning meds ★** | multi-select | Levothyroxine (thyroid) · Metformin · Blood-pressure med · Vitamins/supplements · No, just my pill · + Add your own. Copy: we'll remind you after your window, in the right order; names only, stays on your phone. |
| 8 | **Side-effect concerns** | multi-select | Nausea · Constipation · Low appetite/food noise · Fatigue · Reflux/burping · Nothing yet (ordered by prevalence). |
| 9 | **Goals (non-shaming)** | multi-select | Take my pill correctly every day · Build a streak & stay consistent · Manage side effects · Keep records for my doctor · See my weight trend (optional, last). |
| 10 | **Reminders** | 1-choice | Pill time + when my window clears · Just the pill reminder · No reminders. |
| 11 | **Apple Health** | 1-choice | Connect (pull weight & activity) · Maybe later. Then **Plan reveal**: honest summary of *their* plan (time, wait, sequence, reminders, streak starts) → "Start day 1" **into the free app**. |

The Plan reveal is a real render of the user's answers — **no fabricated "Crafting your plan… 97%" loader**.

> **Shipped-flow reconciliation (2026-07-21):** the built onboarding is an **11-step flow that is the source of truth**. The **Apple Health onboarding step (step 11 above) and a dedicated weight-entry step were deliberately deferred/dropped**: weight stays optional and is logged in-app (via the weigh-in sheet), and Apple Health sync is planned as a later addition rather than an onboarding gate. The step table above reflects the original design; where it diverges from the shipped flow, the shipped flow wins.

## 6. Design — Today home (ritual-first, Direction A)

`TodayView` becomes a single calm scroll. Order:

1. **Header** — "Good morning, {firstName}" + streak flame.
2. **Ritual hero** — the existing `RitualCard`, driven by `RitualState` (`notTaken` → `windowRunning(end:)` → `clear`). Brand-gradient card stating exactly the one thing to do now ("Wait 28 min before food & other meds · clear at 7:32 AM").
3. **Your morning sequence** — checklist from `UserSettings.morningMeds`: the pill (checked when logged) → each morning med ("after window") → breakfast ("after {clear time}"). This is the wedge, made visible daily. Only shown when `morningMeds` is non-empty or the pill requires an empty stomach.
4. **Medication level (preview)** — tappable card with a 7-day sparkline + one-line framing ("Steady daily levels — no peak-and-crash"). Tap → full graph (premium).
5. **Intake counters** — existing water + protein counters (`IntakeCountersView`).
6. **Side effects** — existing quick-log entry (`SideEffectSheet`).

**Central Log sheet (`⊕` FAB):** a floating button on Today opens a bottom sheet of quick log actions — **Took my pill · Weight · Water · Protein · Side effects** (+ *Progress photo* as a premium row). This is the "adopt from MeAgain with our twist" element: pill-native ("Took my pill", not "Log a Shot") and deliberately **no food-database row** (Scan/Search/Voice) since GLPill is not a calorie app. The individual actions reuse existing logging paths (`DoseLog`, `WeightEntry`, `IntakeDay`, `SideEffectLog`).

Navigation stays the current 5 tabs (Today · Progress · History · Report · Settings). Only Today changes.

## 7. Design — Medication-level graph (pill-adapted)

New component. Estimates relative drug level over time from the user's dose + daily log history.

- **Shape:** a daily pill produces small daily increments **climbing to a stable steady-state** over ~a week (contrast MeAgain's weekly-injection peak-and-crash). This is the visual we own: *"steadier levels, fewer ups and downs — by design."*
- **Model:** a simple, transparent relative-level estimate (not a clinical PK model, and labelled "estimated"). Uses a per-drug elimination half-life constant to accumulate logged daily doses into a normalized 0–100% curve. No medical claims; "estimated" label required. Exact math to be pinned in the plan; must be pure and unit-testable.
- **Free:** the full interactive graph (range selector, tap-to-inspect, steady-state annotation) is **free**, matching MeAgain's generosity. Today shows a compact preview card that opens the full graph.
- **Missing data:** if the drug is unknown or few doses logged, show an honest empty/low-confidence state rather than a fake curve.

## 8. Design — Freemium model

Flip from hard paywall to **generous freemium**. The second MeAgain video (see `docs/competitor/meagain/`, 2026-07-21) showed the incumbent gives away nearly the entire app for free — medication-level graph, all tracking, full history and charts — and monetizes only a *thin* "extras" layer (progress photos, a photo "journey" card, premium widgets, food database) plus an opportunistic discount paywall. To not look stingy next to the incumbent, GLPill matches that generosity.

**Pricing:** **$6.99/mo · $39.99/yr, no trial** (the core is already free, so a trial is redundant). Upgrade is honest and in-context — **no fake-scarcity "85% off, you'll never see this again"** paywall.

**Free forever — the whole tracker:**
- Ritual hero + wait-window timer
- Morning-meds sequence (the wedge)
- **Central Log sheet** (the `⊕` FAB): Took my pill · Weight · Water · Protein · Side effects
- Streak + smart reminders (pill + window-clear)
- **Full medication-level graph** (steady-state, all ranges, tap-to-inspect) — *free, not gated*
- **Full dose history**
- **Weight trend + BMI + timeline**
- Streak home-screen widget

**Premium ✦ — thin, high-value, leaning into the medical wedge:**
- **Doctor-ready PDF report** (adherence, doses, side effects) — the flagship upgrade for our T2D/medical audience
- Consistency "Wrapped" & journey share cards
- Advanced widgets — Lock Screen + medication-level widget
- Weight projection (goal-date estimate)
- Data export (CSV) & multiple medications
- Progress photo logging

**Rationale:** everything a pill user needs daily is free, so they feel the difference on day 1 and recommend it. Premium is a small set of "extras" — and unlike MeAgain (which monetizes weight-loss photos), our headline upgrade is the **doctor report**, which fits the medical wedge. The natural upgrade moment is a real one: "I have a clinic appointment — I want the report."

## 9. Data model changes

Existing SwiftData models to extend (additive, migration-safe defaults):

- **`MedicationKind`** (`Core/Models/Medication.swift`): add `.wegovyPill` (display "Wegovy pill (oral semaglutide)", `requiresEmptyStomach = true`). Keep `foundayo`, `rybelsus`, `custom`. Add a per-kind **dose ladder** ([Double]) and reuse `defaultRequiresEmptyStomach`.
- **`UserSettings`** (`Core/Models/UserSettings.swift`): add
  - `waitWindowMinutes: Int = 30` (from step 6; used by `RitualState.windowRunning`),
  - `onboardingStage: String?` (step 2),
  - `sideEffectConcerns: [String] = []` (step 8),
  - `goals: [String] = []` (step 9),
  - `reminderStyle: String = "full"` (step 10: full / pillOnly / none).
  - `morningMeds: [String]` already exists — reused.
- **`RitualState`** (`Features/Today/RitualState.swift`): unchanged logic; `windowEnd` now derives from `waitWindowMinutes` instead of a hard-coded 30.
- **`Entitlement` / `SubscriptionStore`** — unchanged API; **consumers** change (see §10).
- **`TitrationStep`** — unchanged; onboarding step 4 pre-fills `steps` from the per-kind ladder instead of manual-only entry.

## 10. Component architecture

- **Onboarding**: expand `OnboardingFlow.swift` (currently 6 `switch` cases → ~11). Each step is a small private `View`. `OnboardingStore` gains the new fields. Keep the existing `store.complete(in:)` + reminder-scheduling pattern. Consider extracting steps into `Features/Onboarding/Steps/` if the file exceeds ~400 lines (per the many-small-files rule).
- **Freemium flip**: `RootView.swift` currently renders `PaywallView()` when `!subscriptions.isUnlocked`. Change so that after onboarding it **always** renders `MainTabView()`; premium features check entitlement at the feature boundary. Introduce a lightweight `PremiumGate` view-modifier / helper (reads `EntitlementState`) that wraps premium surfaces and presents `PaywallView` as a sheet on tap. `PaywallView` copy shifts from hard-wall to upgrade.
- **Today**: `TodayView` composes existing `RitualCard`, `IntakeCountersView`, `SideEffectSheet` + new subviews: `MorningSequenceCard`, `MedLevelPreviewCard`, and a `LogSheet` presented from the `⊕` FAB. `TodayStore` gains sequence + level-preview derivation (pure).
- **Log sheet**: new `Features/Today/LogSheet.swift` — a bottom sheet routing to existing logging flows (pill/weight/water/protein/side effects); the progress-photo row is premium-gated via `PremiumGate`.
- **Med-level graph**: new `Core/Logic/MedicationLevel.swift` (pure estimator, unit-tested) + `Features/Today/MedLevelPreviewCard.swift` (sparkline) + `Features/Today/MedicationLevelView.swift` (full graph, **free**). Uses Swift Charts.
- **Sequencing**: pure helper deriving the ordered sequence (pill → meds → breakfast) from `RitualState` + `morningMeds` + `waitWindowMinutes`.

## 11. Non-goals / explicitly deferred

- No calorie/macro food database. No AI chat companion. No progress photos. No social/leaderboards.
- No clinical PK modeling or any interaction *advice* — timing/education only.
- Other tabs (Progress/History/Report/Settings) keep their current design; they gain only premium-gating where §8 applies.

## 12. Testing

- **Pure logic (unit, Swift Testing):** `RitualState.make` across `waitWindowMinutes`; morning-sequence derivation (empty meds, with meds, Foundayo no-window); `MedicationLevel` estimator (steady-state monotonic climb, missing-data empty state, per-drug half-life); onboarding store field persistence; entitlement gating decisions.
- **Freemium boundary:** the whole app (incl. med-level graph, full history, weight trends, the Log sheet) is reachable when `locked`; only the thin premium surfaces (doctor PDF report, Wrapped/journey cards, advanced widgets, weight projection, data export, progress-photo row) present the upgrade sheet when `locked` and render when `active`.
- **Onboarding:** each step advances, "Not sure"/"Skip" never blocks, `store.complete` writes all new fields.
- **UI test:** onboarding completes → lands on Today (not paywall); tapping a premium card shows the upgrade sheet.
- Keep the existing suite green; maintain the project's ≥80% coverage bar. Note the 2 known pre-existing failures (headless StoreKit config; onboarding→paywall UI test — the latter changes meaning under freemium and must be updated).

## 13. Open questions (resolve in planning)

1. Exact medication-level estimator math + per-drug half-life constants (semaglutide ~7 days; orforglipron — pin from label/PK before implementing; fall back to a labelled generic curve if unverifiable).
2. Whether "switching from injections" (step 2) unlocks any extra first-run coaching, or is analytics-only for now.
3. Migration handling for existing installed users (v1.0 testers) — default the new `UserSettings` fields and don't force re-onboarding.
