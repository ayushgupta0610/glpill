# GLPill Pill Co-Pilot Experience — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-anchor GLPill on the "daily pill co-pilot" wedge — a generous-free experience with a ritual-first Today, morning-meds sequencing, a pill-adapted medication-level graph, a central Log sheet, an 11-step honest onboarding, and a freemium flip (whole app free; thin premium).

**Architecture:** Additive SwiftData model changes drive a freemium flip (gate premium at the feature boundary via a `PremiumGate`, not the whole app in `RootView`), Today-tab enrichments (compose existing `RitualCard`/`IntakeCountersView`/`SideEffectSheet` with new `MorningSequenceCard`, `MedLevelPreviewCard`, `LogSheet`), a pure `MedicationLevel` estimator rendered with Swift Charts, and an expanded `OnboardingFlow`. Pure logic is TDD'd with Swift Testing; SwiftUI views get concrete construction + manual verification steps.

**Tech Stack:** SwiftUI, SwiftData, StoreKit 2, Swift Charts, Swift Testing, XcodeGen (`xcodegen generate` before builds).

**Spec:** `docs/superpowers/specs/2026-07-21-glpill-pill-copilot-experience-design.md`

**Conventions:**
- `project.yml` and `GLPill.xcodeproj` are at the **repo root**. Run `xcodegen generate` **from the repo root** after adding any new source file (new files must be picked up by the project). Do NOT `cd App` first.
- Unit tests live in `App/Tests/` (target `GLPillTests`); UI tests in `App/UITests/GLPillUITests.swift` (target `GLPillUITests`). **Several test files already exist** (`OnboardingStoreTests.swift`, `TodayStoreTests.swift`, `MorningMedsTests.swift`, `SubscriptionGateTests.swift`, `StoreKitConfigTests.swift`, `RitualStateTests.swift`, …) — ADD new `@Test` cases to the existing file when one exists; only create a new file when none matches. Check with `ls App/Tests` first.
- Build/test: `xcodebuild -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test` (simulator forces local store via the existing `#if targetEnvironment(simulator)` guard).
- Commit after every green step. Conventional commits (`feat:`/`test:`/`refactor:`). No attribution footer (disabled globally).
- The app currently HARD-gates behind the paywall in `RootView.swift`; Phase 2 flips that. Do Phase 1 → 2 first so later UI has a place to run free.

---

## File Structure

**Create:**
- `App/Sources/Core/Models/MedicationLadder.swift` — per-`MedicationKind` dose ladder + display metadata (pure).
- `App/Sources/Core/Logic/MorningSequence.swift` — pure derivation of the ordered morning sequence.
- `App/Sources/Core/Logic/MedicationLevel.swift` — pure estimated-drug-level curve.
- `App/Sources/Core/Purchases/PremiumGate.swift` — view-modifier + helper gating premium surfaces.
- `App/Sources/Features/Today/MorningSequenceCard.swift` — "Your morning sequence" checklist.
- `App/Sources/Features/Today/MedLevelPreviewCard.swift` — sparkline preview card.
- `App/Sources/Features/Today/MedicationLevelView.swift` — full interactive graph (free).
- `App/Sources/Features/Today/LogSheet.swift` — central `⊕` log bottom sheet.
- `App/Sources/Features/Onboarding/Steps/` — new step views (StageStep, DoseLadderStep, WaitWindowStep, ConcernsStep, GoalsStep, ReminderStyleStep, PlanRevealStep).
- Test files mirroring each pure unit under `App/Tests/`.

**Modify:**
- `App/Sources/Core/Models/Medication.swift` — add `.wegovyPill`, ladder hook.
- `App/Sources/Core/Models/UserSettings.swift` — add `waitWindowMinutes`, `onboardingStage`, `sideEffectConcerns`, `goals`, `reminderStyle`.
- `App/Sources/Core/Purchases/SubscriptionStore.swift` — add `isPremium` alias (semantic clarity) — optional.
- `App/Sources/App/RootView.swift` — freemium flip.
- `App/Sources/Features/Today/TodayView.swift` — wire `waitWindowMinutes`, add sequence/preview/Log FAB.
- `App/Sources/Features/Today/TodayStore.swift` — add `logWeight`.
- `App/Sources/Features/Onboarding/OnboardingFlow.swift` + `OnboardingStore.swift` — expand to 11 steps.

---

## Phase 1 — Data model foundation

### Task 1: Add `.wegovyPill` to `MedicationKind`

**Files:**
- Modify: `App/Sources/Core/Models/Medication.swift`
- Test: `App/Tests/MedicationKindTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import GLPill

struct MedicationKindTests {
    @Test("Wegovy pill requires an empty stomach")
    func wegovyPillEmptyStomach() {
        #expect(MedicationKind.wegovyPill.defaultRequiresEmptyStomach == true)
        #expect(MedicationKind.wegovyPill.defaultDisplayName == "Wegovy pill (oral semaglutide)")
    }

    @Test("Foundayo has no empty-stomach rule")
    func foundayoNoWindow() {
        #expect(MedicationKind.foundayo.defaultRequiresEmptyStomach == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep -i 'MedicationKindTests\|error'`
Expected: FAIL — `wegovyPill` not a member of `MedicationKind`.

- [ ] **Step 3: Add the case and metadata**

In `Medication.swift`, add `case wegovyPill` after `rybelsus`, and update the switches:

```swift
enum MedicationKind: String, Codable, CaseIterable {
    case foundayo
    case rybelsus
    case wegovyPill
    case custom

    var defaultDisplayName: String {
        switch self {
        case .foundayo: return "Foundayo (orforglipron)"
        case .rybelsus: return "Rybelsus (semaglutide)"
        case .wegovyPill: return "Wegovy pill (oral semaglutide)"
        case .custom: return "Custom medication"
        }
    }

    var defaultRequiresEmptyStomach: Bool {
        self == .rybelsus || self == .wegovyPill
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add App/Sources/Core/Models/Medication.swift App/Tests/MedicationKindTests.swift
git commit -m "feat: add Wegovy pill medication kind"
```

### Task 2: Per-kind dose ladders

**Files:**
- Create: `App/Sources/Core/Models/MedicationLadder.swift`
- Test: `App/Tests/MedicationLadderTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import GLPill

struct MedicationLadderTests {
    @Test("Rybelsus ladder is 3, 7, 14")
    func rybelsus() { #expect(MedicationLadder.doses(for: .rybelsus) == [3, 7, 14]) }

    @Test("Foundayo ladder matches the FDA titration")
    func foundayo() { #expect(MedicationLadder.doses(for: .foundayo) == [0.8, 2.5, 5.5, 9, 14.5, 17.2]) }

    @Test("Wegovy pill ladder is 1.5, 4, 9, 25")
    func wegovy() { #expect(MedicationLadder.doses(for: .wegovyPill) == [1.5, 4, 9, 25]) }

    @Test("Custom has no preset ladder")
    func custom() { #expect(MedicationLadder.doses(for: .custom).isEmpty) }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild ... test 2>&1 | grep -i 'MedicationLadder\|error'`
Expected: FAIL — no such type.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Verified FDA titration ladders per pill (mg). Presented in onboarding as
/// tappable dose options; the app never recommends escalating — it only lets a
/// user record the dose their prescriber gave them.
enum MedicationLadder {
    static func doses(for kind: MedicationKind) -> [Double] {
        switch kind {
        case .rybelsus: return [3, 7, 14]
        case .foundayo: return [0.8, 2.5, 5.5, 9, 14.5, 17.2]
        case .wegovyPill: return [1.5, 4, 9, 25]
        case .custom: return []
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add App/Sources/Core/Models/MedicationLadder.swift App/Tests/MedicationLadderTests.swift
git commit -m "feat: per-kind dose ladders"
```

### Task 3: Extend `UserSettings`

**Files:**
- Modify: `App/Sources/Core/Models/UserSettings.swift`
- Test: `App/Tests/UserSettingsTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import SwiftData
@testable import GLPill

@MainActor
struct UserSettingsTests {
    @Test("New fields default safely for existing installs")
    func defaults() {
        let s = UserSettings()
        #expect(s.waitWindowMinutes == 30)
        #expect(s.onboardingStage == nil)
        #expect(s.sideEffectConcerns.isEmpty)
        #expect(s.goals.isEmpty)
        #expect(s.reminderStyle == "full")
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL (no such properties).

- [ ] **Step 3: Add the properties**

Add to `UserSettings` (properties + `init` params, all defaulted so SwiftData lightweight-migrates existing stores):

```swift
    /// Minutes to wait before food/other meds after an empty-stomach pill (step 6).
    var waitWindowMinutes: Int = 30
    /// Onboarding stage answer (step 2), e.g. "aboutToStart" / "switchingFromInjections". Analytics/coaching only.
    var onboardingStage: String?
    /// Side-effect concerns chosen in onboarding (step 8). Seeds quick-log ordering.
    var sideEffectConcerns: [String] = []
    /// Goals chosen in onboarding (step 9). Non-shaming; tunes emphasis.
    var goals: [String] = []
    /// Reminder preference (step 10): "full" | "pillOnly" | "none".
    var reminderStyle: String = "full"
```

Add matching defaulted params to `init(...)` and assignments, following the existing pattern (see `morningMeds`).

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Core/Models/UserSettings.swift App/Tests/UserSettingsTests.swift
git commit -m "feat: onboarding+ritual fields on UserSettings"
```

---

## Phase 2 — Freemium flip

### Task 4: `PremiumGate` helper

**Files:**
- Create: `App/Sources/Core/Purchases/PremiumGate.swift`
- Test: `App/Tests/PremiumGateTests.swift`

- [ ] **Step 1: Write the failing test** (pure decision function, no SwiftUI)

```swift
import Testing
@testable import GLPill

struct PremiumGateTests {
    @Test("Locked hides premium content and shows the upgrade")
    func locked() { #expect(PremiumGate.shouldShowUpgrade(for: .locked) == true) }

    @Test("Active reveals premium content")
    func active() { #expect(PremiumGate.shouldShowUpgrade(for: .active) == false) }

    @Test("Unknown is treated as locked (fail closed)")
    func unknown() { #expect(PremiumGate.shouldShowUpgrade(for: .unknown) == true) }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL (no `PremiumGate`).

- [ ] **Step 3: Implement the helper + view modifier**

```swift
import SwiftUI

/// Gates premium-only surfaces. Free features never call this. When locked (or
/// unknown), tapping a gated control presents the paywall as a sheet instead of
/// running the action.
enum PremiumGate {
    static func shouldShowUpgrade(for state: EntitlementState) -> Bool {
        state != .active
    }
}

private struct PremiumTapModifier: ViewModifier {
    @Environment(SubscriptionStore.self) private var subscriptions
    @State private var showPaywall = false
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if PremiumGate.shouldShowUpgrade(for: subscriptions.state) {
                    showPaywall = true
                } else {
                    action()
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}

extension View {
    /// Runs `action` when the user is premium; otherwise presents the paywall.
    func premiumAction(_ action: @escaping () -> Void) -> some View {
        modifier(PremiumTapModifier(action: action))
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add App/Sources/Core/Purchases/PremiumGate.swift App/Tests/PremiumGateTests.swift
git commit -m "feat: PremiumGate for feature-level gating"
```

### Task 5: Flip `RootView` to freemium

**Files:**
- Modify: `App/Sources/App/RootView.swift`

- [ ] **Step 1: Update the routing**

Replace the `body` `Group` so the app is always reachable after onboarding; the paywall is no longer a full-screen gate:

```swift
        Group {
            if !onboardingComplete {
                OnboardingFlow()
            } else {
                MainTabView()
            }
        }
```

Delete the now-unused `subscriptions.isUnlocked` / `.state == .unknown` / `loadingSplash` branches **and** the `LoadingSplashView` struct if nothing else references it (grep first: `grep -rn LoadingSplashView App/Sources`). Keep the `storageFailed` safe-area inset.

- [ ] **Step 2: Update the paywall copy for upgrade context**

In `App/Sources/Features/Paywall/PaywallView.swift`, change the hero headline/subtext from wall framing to upgrade framing (e.g. title "Unlock GLPill Premium", subtitle listing the thin premium set). Keep the existing product/purchase plumbing. Remove any 7-day-trial copy (see Task 6).

- [ ] **Step 3: Update the onboarding→app UI test**

`App/UITests/GLPillUITests.swift` `testOnboardingLeadsToPaywall` must become `testOnboardingLeadsToTodayTab`: after completing onboarding, assert the "Today" tab exists (not the paywall). Update the assertion accordingly.

- [ ] **Step 4: Build & run tests**

Run: `xcodebuild -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: builds; app opens to Today after onboarding; no full-screen paywall.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/App/RootView.swift App/Sources/Features/Paywall/PaywallView.swift App/UITests/GLPillUITests.swift
git commit -m "feat: flip to freemium — app free, paywall is in-context upgrade"
```

### Task 6: Drop the 7-day trial

**Files:**
- Modify: `App/Resources/GLPill.storekit` (remove `introductoryOffer` free-trial blocks from both products)
- Modify: any paywall copy referencing "7-day" / "free trial" (grep: `grep -rn -i 'trial\|7-day\|7 day' App/Sources`)

- [ ] **Step 1:** Open `GLPill.storekit`, delete the `introductoryOffer` (free trial) from `glpill.pro.monthly` and `glpill.pro.yearly`.
- [ ] **Step 2:** Remove trial wording from `PaywallView.swift`/onboarding copy so the UI never promises a trial.
- [ ] **Step 3:** Update `App/Tests/StoreKitConfigTests.swift` — the stale yearly-trial assertion becomes "no introductory offer configured". (This is one of the two known-failing tests; fixing it here is expected.)
- [ ] **Step 4:** Run: `xcodebuild ... test 2>&1 | grep -i StoreKitConfig`. Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add App/Resources/GLPill.storekit App/Sources/Features/Paywall/PaywallView.swift App/Tests/StoreKitConfigTests.swift
git commit -m "chore: drop 7-day trial (core is free under freemium)"
```

---

## Phase 3 — Today enrichment

### Task 7: Wire `waitWindowMinutes` into the eat timer

**Files:**
- Modify: `App/Sources/Features/Today/TodayView.swift`

- [ ] **Step 1:** In `takePill()`, replace the hard-coded 30-minute window with the user's setting:

```swift
            if startTimer {
                let minutes = settingsList.first?.waitWindowMinutes ?? 30
                eatTimerEnd = Date().addingTimeInterval(Double(minutes) * 60).timeIntervalSince1970
                ReminderScheduler.scheduleEatTimer(
                    using: UNNotificationScheduler(),
                    meds: settingsList.first?.morningMeds ?? []
                )
            }
```

- [ ] **Step 2:** Build & run; log a dose with a Rybelsus medication and confirm the timer reflects the configured window.

Run: `xcodebuild ... build 2>&1 | tail -5` — Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add App/Sources/Features/Today/TodayView.swift
git commit -m "feat: eat timer honors waitWindowMinutes"
```

### Task 8: `MorningSequence` pure derivation

**Files:**
- Create: `App/Sources/Core/Logic/MorningSequence.swift`
- Test: `App/Tests/MorningSequenceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import GLPill

struct MorningSequenceTests {
    private let clear = Date(timeIntervalSince1970: 1_000_000)

    @Test("Pill + meds produce ordered steps with a window")
    func withMeds() {
        let steps = MorningSequence.make(pillTaken: true, pillName: "Foundayo", hadWindow: true,
                                         clearTime: clear, meds: ["Levothyroxine"])
        #expect(steps.count == 3)
        #expect(steps[0].title == "Foundayo")
        #expect(steps[0].done == true)
        #expect(steps[1].title == "Levothyroxine")
        #expect(steps[2].title == "Breakfast")
    }

    @Test("No empty-stomach window drops the wait framing")
    func noWindow() {
        let steps = MorningSequence.make(pillTaken: false, pillName: "Foundayo", hadWindow: false,
                                         clearTime: nil, meds: [])
        #expect(steps.count == 1)
        #expect(steps[0].done == false)
        #expect(steps[0].subtitle == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL (no type).

- [ ] **Step 3: Implement**

```swift
import Foundation

/// A pure, unit-tested description of the user's morning order:
/// pill → (after window) other meds → breakfast. Timing metadata only.
struct MorningSequence {
    struct Step: Equatable {
        let title: String
        let subtitle: String?
        let done: Bool
    }

    static func make(pillTaken: Bool, pillName: String, hadWindow: Bool,
                     clearTime: Date?, meds: [String]) -> [Step] {
        var steps: [Step] = [
            Step(title: pillName,
                 subtitle: pillTaken ? "Taken" : nil,
                 done: pillTaken)
        ]
        guard pillTaken else { return steps }

        let after: String? = {
            guard hadWindow, let clearTime else { return nil }
            return "After \(clearTime.formatted(date: .omitted, time: .shortened))"
        }()

        for med in meds {
            steps.append(Step(title: med, subtitle: after ?? "OK now", done: false))
        }
        steps.append(Step(title: "Breakfast", subtitle: after ?? "OK now", done: false))
        return steps
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add App/Sources/Core/Logic/MorningSequence.swift App/Tests/MorningSequenceTests.swift
git commit -m "feat: pure morning-sequence derivation"
```

### Task 9: `MorningSequenceCard` view + place on Today

**Files:**
- Create: `App/Sources/Features/Today/MorningSequenceCard.swift`
- Modify: `App/Sources/Features/Today/TodayView.swift`

- [ ] **Step 1: Build the card view**

```swift
import SwiftUI

struct MorningSequenceCard: View {
    let steps: [MorningSequence.Step]

    var body: some View {
        Card {
            SectionHeader(title: "Your morning sequence")
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                HStack(spacing: 12) {
                    Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(step.done ? Theme.primary : Color.secondary.opacity(0.5))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.title).font(.subheadline.weight(.medium))
                        if let subtitle = step.subtitle {
                            Text(subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}
```

- [ ] **Step 2: Compose it on Today** — in `TodayView.body`, after `ritualCard` and before `streakCard`, insert (only when there is a sequence worth showing):

```swift
                    if !morningSequence.isEmpty && (medications.first?.requiresEmptyStomach == true || !(settingsList.first?.morningMeds ?? []).isEmpty) {
                        MorningSequenceCard(steps: morningSequence)
                    }
```

Add the computed property to `TodayView`:

```swift
    private var morningSequence: [MorningSequence.Step] {
        let clear = eatTimerEnd > 0 ? Date(timeIntervalSince1970: eatTimerEnd) : nil
        return MorningSequence.make(
            pillTaken: todayLog != nil,
            pillName: medications.first?.displayName ?? "Your GLP-1 pill",
            hadWindow: medications.first?.requiresEmptyStomach ?? false,
            clearTime: clear,
            meds: settingsList.first?.morningMeds ?? []
        )
    }
```

- [ ] **Step 3: Build & manually verify** — log a Rybelsus dose with a morning med set; the sequence card appears with the pill checked and "After HH:MM" on the med + breakfast.

Run: `xcodebuild ... build 2>&1 | tail -5` — Expected: success.

- [ ] **Step 4: Commit**

```bash
xcodegen generate
git add App/Sources/Features/Today/MorningSequenceCard.swift App/Sources/Features/Today/TodayView.swift
git commit -m "feat: morning-sequence card on Today"
```

### Task 10: `TodayStore.logWeight`

**Files:**
- Modify: `App/Sources/Features/Today/TodayStore.swift`
- Test: `App/Tests/TodayStoreWeightTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import SwiftData
@testable import GLPill

@MainActor
struct TodayStoreWeightTests {
    private func context() throws -> ModelContext {
        let c = try ModelContainer(for: WeightEntry.self,
            configurations: .init(isStoredInMemoryOnly: true))
        return ModelContext(c)
    }

    @Test("logWeight inserts a WeightEntry")
    func logs() throws {
        let ctx = try context()
        let store = TodayStore(context: ctx)
        try store.logWeight(kilograms: 80)
        let entries = try ctx.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.kilograms == 80)
    }
}
```

Confirm `WeightEntry`'s property name first (`grep -n 'var ' App/Sources/Core/Models/WeightEntry.swift`); adjust `kilograms` to the real name.

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL (no `logWeight`).

- [ ] **Step 3: Implement** (in `TodayStore`, mirroring `logSideEffect`):

```swift
    func logWeight(kilograms: Double, on date: Date = .now) throws {
        context.insert(WeightEntry(date: calendar.startOfDay(for: date), kilograms: kilograms))
        try context.save()
    }
```

Match `WeightEntry`'s real initializer signature.

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Features/Today/TodayStore.swift App/Tests/TodayStoreWeightTests.swift
git commit -m "feat: logWeight on TodayStore"
```

### Task 11: `LogSheet` + `⊕` FAB on Today

**Files:**
- Create: `App/Sources/Features/Today/LogSheet.swift`
- Modify: `App/Sources/Features/Today/TodayView.swift`

- [ ] **Step 1: Build the sheet** — pill-native rows; progress-photo row is premium-gated:

```swift
import SwiftUI

struct LogSheet: View {
    let onPill: () -> Void
    let onWeight: () -> Void
    let onWater: () -> Void
    let onProtein: () -> Void
    let onSideEffect: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                row("pills.fill", "Took my pill", onPill)
                row("scalemass.fill", "Weight", onWeight)
                row("drop.fill", "Water", onWater)
                row("fork.knife", "Protein", onProtein)
                row("bandage.fill", "Side effects", onSideEffect)
                HStack {
                    Label("Progress photo", systemImage: "camera.fill")
                    Spacer()
                    Text("Premium").font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .premiumAction { /* photo capture — implemented with the premium photo feature */ }
            }
            .navigationTitle("Log for today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }

    private func row(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button { action(); dismiss() } label: {
            Label(title, systemImage: icon)
        }
    }
}
```

- [ ] **Step 2: Add the FAB + presentation to `TodayView`** — add `@State private var showLogSheet = false`, overlay a floating button on the `ScrollView`, and present the sheet:

```swift
            .overlay(alignment: .bottomTrailing) {
                Button { showLogSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Theme.primary, in: Circle())
                        .shadow(radius: 8, y: 4)
                }
                .padding()
                .accessibilityLabel("Log something")
            }
            .sheet(isPresented: $showLogSheet) {
                LogSheet(
                    onPill: takePill,
                    onWeight: { showWeightSheet = true },
                    onWater: { withErrorHandling { try store.addWater(metricDefaultWater) } },
                    onProtein: { withErrorHandling { try store.addProtein(25) } },
                    onSideEffect: { showSideEffectSheet = true }
                )
            }
```

Add a simple weight-entry sheet (`showWeightSheet` + a `DatePicker`-style numeric entry calling `store.logWeight`), or route to the existing weight-log screen if one exists (`grep -rn 'logWeight\|WeightEntry(' App/Sources/Features/Progress`). Reuse the existing screen if present rather than duplicating. Define `metricDefaultWater` as the existing default increment (237 ml / 8 oz).

- [ ] **Step 3: Build & manually verify** — the FAB opens the sheet; each row logs and dismisses; the photo row shows the paywall when locked.

Run: `xcodebuild ... build 2>&1 | tail -5` — Expected: success.

- [ ] **Step 4: Commit**

```bash
xcodegen generate
git add App/Sources/Features/Today/LogSheet.swift App/Sources/Features/Today/TodayView.swift
git commit -m "feat: central pill-native Log sheet + FAB"
```

---

## Phase 4 — Medication-level graph

### Task 12: `MedicationLevel` pure estimator

**Files:**
- Create: `App/Sources/Core/Logic/MedicationLevel.swift`
- Test: `App/Tests/MedicationLevelTests.swift`

**Model:** relative accumulated level using first-order elimination: `level(t) = Σ dose_i · 0.5^((t − t_i)/halfLife)`. Half-life per drug: semaglutide (Rybelsus/Wegovy pill) ≈ 168 h; orforglipron ≈ 48 h (ESTIMATE — flagged in spec §13 to verify against label; labelled "estimated" in UI). Output is a sampled curve; not clinical.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import GLPill

struct MedicationLevelTests {
    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 86_400) }

    @Test("Empty log yields an empty curve")
    func empty() {
        #expect(MedicationLevel.curve(doses: [], halfLifeHours: 168, samples: 10, now: day(5)).isEmpty)
    }

    @Test("Daily dosing climbs monotonically toward steady state")
    func climbs() {
        let doses = (0..<7).map { (date: day($0), mg: 7.0) }
        let curve = MedicationLevel.curve(doses: doses, halfLifeHours: 168, samples: 7, now: day(6))
        for i in 1..<curve.count { #expect(curve[i].level >= curve[i - 1].level) }
        #expect(curve.last!.level > curve.first!.level)
    }

    @Test("Half-life decay: one dose halves after one half-life")
    func decay() {
        let start = day(0)
        let curve = MedicationLevel.curve(doses: [(date: start, mg: 10)], halfLifeHours: 24,
                                          samples: 2, now: start.addingTimeInterval(24 * 3600))
        #expect(abs(curve.last!.level - 5) < 0.01)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL (no type).

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Estimated (NOT clinical) relative medication level from logged daily doses,
/// using first-order elimination. Labelled "estimated" wherever shown.
enum MedicationLevel {
    struct Point: Equatable { let date: Date; let level: Double }

    static func halfLifeHours(for kind: MedicationKind) -> Double {
        switch kind {
        case .rybelsus, .wegovyPill: return 168   // semaglutide ~7 days
        case .foundayo: return 48                 // orforglipron ~2 days (estimate; verify vs label)
        case .custom: return 96
        }
    }

    /// Samples the accumulated level from the first dose to `now`.
    static func curve(doses: [(date: Date, mg: Double)], halfLifeHours: Double,
                      samples: Int, now: Date) -> [Point] {
        guard let first = doses.map(\.date).min(), samples > 1, halfLifeHours > 0 else { return [] }
        let span = now.timeIntervalSince(first)
        guard span > 0 else { return [] }
        let k = log(2) / (halfLifeHours * 3600)
        return (0..<samples).map { i in
            let t = first.addingTimeInterval(span * Double(i) / Double(samples - 1))
            let level = doses.reduce(0.0) { acc, dose in
                let dt = t.timeIntervalSince(dose.date)
                return dt < 0 ? acc : acc + dose.mg * exp(-k * dt)
            }
            return Point(date: t, level: level)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add App/Sources/Core/Logic/MedicationLevel.swift App/Tests/MedicationLevelTests.swift
git commit -m "feat: estimated medication-level curve"
```

### Task 13: Preview card + full graph view (free)

**Files:**
- Create: `App/Sources/Features/Today/MedLevelPreviewCard.swift`
- Create: `App/Sources/Features/Today/MedicationLevelView.swift`
- Modify: `App/Sources/Features/Today/TodayView.swift`

- [ ] **Step 1: Full graph view** (Swift Charts, free):

```swift
import SwiftUI
import Charts

struct MedicationLevelView: View {
    let points: [MedicationLevel.Point]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimated medication level").font(.headline)
            Text("Steady daily levels — no peak-and-crash. Estimated, not a medical reading.")
                .font(.caption).foregroundStyle(.secondary)
            if points.isEmpty {
                ContentUnavailableView("Log a few doses to see your level build",
                                       systemImage: "chart.line.uptrend.xyaxis")
            } else {
                Chart(points, id: \.date) { p in
                    AreaMark(x: .value("Day", p.date), y: .value("Level", p.level))
                        .foregroundStyle(Theme.primary.opacity(0.25))
                    LineMark(x: .value("Day", p.date), y: .value("Level", p.level))
                        .foregroundStyle(Theme.primary)
                }
                .frame(height: 220)
            }
        }
        .padding()
    }
}
```

- [ ] **Step 2: Preview card** (compact, taps into the full view):

```swift
import SwiftUI
import Charts

struct MedLevelPreviewCard: View {
    let points: [MedicationLevel.Point]

    var body: some View {
        NavigationLink { MedicationLevelView(points: points) } label: {
            Card {
                HStack {
                    SectionHeader(title: "Medication level")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
                if points.isEmpty {
                    Text("Log doses to see your steady-state build")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Chart(points, id: \.date) { p in
                        LineMark(x: .value("Day", p.date), y: .value("Level", p.level))
                            .foregroundStyle(Theme.primary)
                    }
                    .chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 48)
                    Text("Steady daily levels — no peak-and-crash")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Compose on Today** — after `MorningSequenceCard`, insert `MedLevelPreviewCard(points: medLevelPoints)` and add:

```swift
    private var medLevelPoints: [MedicationLevel.Point] {
        let doses = doseLogs.map { (date: $0.takenAt, mg: $0.doseMg) }
        let kind = medications.first?.kind ?? .custom
        return MedicationLevel.curve(doses: doses,
                                     halfLifeHours: MedicationLevel.halfLifeHours(for: kind),
                                     samples: 40, now: .now)
    }
```

- [ ] **Step 4: Build & manually verify** — with several logged doses the preview shows the climbing line and taps into the full chart.

Run: `xcodebuild ... build 2>&1 | tail -5` — Expected: success.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add App/Sources/Features/Today/MedLevelPreviewCard.swift App/Sources/Features/Today/MedicationLevelView.swift App/Sources/Features/Today/TodayView.swift
git commit -m "feat: medication-level preview + full graph (free)"
```

---

## Phase 5 — Onboarding redesign (6 → 11 steps)

**Approach:** Expand `OnboardingStore` with the new answers, then grow `OnboardingFlow`'s `switch` to the new step sequence. Reuse the existing single-select card pattern from `MedicationStep` and the chip pattern from `MorningMedsStep`. Extract new step views into `Features/Onboarding/Steps/`. Each new step view is small and self-contained.

### Task 14: Expand `OnboardingStore`

**Files:**
- Modify: `App/Sources/Features/Onboarding/OnboardingStore.swift`
- Test: `App/Tests/OnboardingStoreTests.swift`

- [ ] **Step 1: Write the failing test** (grounding on the real `complete(in:)`):

```swift
import Testing
import SwiftData
@testable import GLPill

@MainActor
struct OnboardingStoreTests {
    @Test("complete persists new onboarding answers")
    func persists() throws {
        let c = try ModelContainer(for: UserSettings.self, Medication.self, TitrationStep.self,
            configurations: .init(isStoredInMemoryOnly: true))
        let ctx = ModelContext(c)
        let store = OnboardingStore()
        store.kind = .wegovyPill
        store.stage = "switchingFromInjections"
        store.waitWindowMinutes = 45
        store.concerns = ["nausea"]
        store.goals = ["consistency"]
        store.reminderStyle = "pillOnly"
        try store.complete(in: ctx)
        let s = try ctx.fetch(FetchDescriptor<UserSettings>()).first
        #expect(s?.waitWindowMinutes == 45)
        #expect(s?.onboardingStage == "switchingFromInjections")
        #expect(s?.sideEffectConcerns == ["nausea"])
        #expect(s?.goals == ["consistency"])
        #expect(s?.reminderStyle == "pillOnly")
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL (missing store fields).

- [ ] **Step 3: Add fields + persist** — add to `OnboardingStore`: `var stage: String?`, `var waitWindowMinutes = 30`, `var concerns: [String] = []`, `var goals: [String] = []`, `var reminderStyle = "full"`. In `complete(in:)`, set the matching `UserSettings` fields when creating/updating settings.

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Features/Onboarding/OnboardingStore.swift App/Tests/OnboardingStoreTests.swift
git commit -m "feat: onboarding store carries new answers"
```

### Task 15: New step views

**Files:**
- Create: `App/Sources/Features/Onboarding/Steps/StageStep.swift`, `DoseLadderStep.swift`, `WaitWindowStep.swift`, `ConcernsStep.swift`, `GoalsStep.swift`, `ReminderStyleStep.swift`, `PlanRevealStep.swift`

Each uses the existing card/chip visual language (see `MedicationStep`/`MorningMedsStep` in `OnboardingFlow.swift`). Build them one per step, each with a `store` binding and a `next`/`finish` closure. Representative full code for the two most distinctive:

- [ ] **Step 1: `WaitWindowStep`** (single-select, conditional on empty-stomach drug):

```swift
import SwiftUI

struct WaitWindowStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    private let options: [(min: Int, label: String, note: String)] = [
        (30, "30 minutes", "the minimum"), (45, "45 minutes", ""),
        (60, "1 hour", ""), (120, "As long as I can", "up to 2h")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How long can you wait before breakfast?").font(.title.bold()).padding(.top, 24)
            Text("You must wait at least 30 minutes. Waiting longer absorbs more of the medicine — we'll time it for you.")
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(options, id: \.min) { opt in
                Button { store.waitWindowMinutes = opt.min } label: {
                    HStack {
                        Text(opt.label).font(.headline).foregroundStyle(.primary)
                        if !opt.note.isEmpty { Text("· \(opt.note)").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Image(systemName: store.waitWindowMinutes == opt.min ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(store.waitWindowMinutes == opt.min ? Theme.primary : .secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                }.buttonStyle(.plain)
            }
            Spacer()
            PillCTAButton(title: "Continue", systemImage: "arrow.right") { next() }.padding(.bottom, 24)
        }.padding(.horizontal).background(Color(.systemGroupedBackground))
    }
}
```

- [ ] **Step 2: `DoseLadderStep`** (single-select from `MedicationLadder.doses(for:)` + "Not sure"; writes the chosen dose into `store.steps` as the current step). Mirror `MedicationStep`'s card layout; source options from `MedicationLadder.doses(for: store.kind)`; append a "Not sure" option that leaves the dose unset.

- [ ] **Step 3:** Build `StageStep`, `ConcernsStep` (multi-select into `store.concerns`), `GoalsStep` (multi-select into `store.goals`), `ReminderStyleStep` (single-select into `store.reminderStyle`), and `PlanRevealStep` (gradient summary of the user's answers — pill, time, wait window, first morning med, "Start day 1" → `finish`; NO fake loader). Each follows the same card/CTA pattern.

- [ ] **Step 4:** Build after each file (`xcodegen generate` first). Expected: compiles.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add App/Sources/Features/Onboarding/Steps/
git commit -m "feat: new onboarding step views"
```

### Task 16: Wire the 11-step flow

**Files:**
- Modify: `App/Sources/Features/Onboarding/OnboardingFlow.swift`

- [ ] **Step 1:** Set `totalSteps = 11`; replace the `switch` with the new order: 0 Welcome, 1 Stage, 2 Medication, 3 DoseLadder, 4 daily time (reuse `ReminderStep`-style time picker for the pill time), 5 WaitWindow (skip when `!store.requiresEmptyStomach` — advance twice), 6 MorningMeds (existing), 7 Concerns, 8 Goals, 9 ReminderStyle, 10 PlanReveal (calls `complete`). Add a `store.requiresEmptyStomach` computed helper (`store.kind.defaultRequiresEmptyStomach`).

- [ ] **Step 2:** For the WaitWindow skip, in `advance()` special-case: if moving into step 5 and `!store.requiresEmptyStomach`, `step += 2`. Add a matching reassurance micro-copy on the medication step for Foundayo (already present).

- [ ] **Step 3:** Update the WelcomeStep copy to lead with the co-pilot line (spec §5 step 1); keep the disclaimer.

- [ ] **Step 4:** Build & run onboarding end-to-end on the simulator for each drug (Rybelsus shows wait-window; Foundayo skips it) → lands on Today.

Run: `xcodebuild ... test 2>&1 | tail -20` — Expected: onboarding UI test (renamed in Task 5) passes; suite green.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Features/Onboarding/OnboardingFlow.swift
git commit -m "feat: 11-step pill-first onboarding flow"
```

---

## Phase 6 — Verification

### Task 17: Full suite + coverage + manual pass

- [ ] **Step 1:** `xcodegen generate && xcodebuild -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -30`. Expected: all green except the one known headless StoreKit case (XCTSkip) — confirm no NEW failures.
- [ ] **Step 2:** Manual smoke on simulator (use the click-drag scroll, since simulator scroll-wheel doesn't map to touch): complete onboarding for Rybelsus → Today shows ritual hero, morning sequence, med-level preview, Log FAB → log dose, weight, water, protein, side effect → tap med-level → full graph → tap Progress-photo row → paywall appears.
- [ ] **Step 3:** Confirm the app is fully usable without purchasing (freemium), and premium rows show the upgrade.
- [ ] **Step 4: Commit any fixes**, then final:

```bash
git add -A && git commit -m "test: verify pill co-pilot experience end-to-end"
```

---

## Self-review notes (carried into execution)

- **Spec coverage:** onboarding (T14–16), Today ritual-first + sequence (T7–9), med-level graph free (T12–13), Log sheet (T11), freemium flip + thin premium + no trial (T4–6), data model (T1–3). Progress/History/Report/Settings deliberately untouched (spec §3 non-goals).
- **Open questions (spec §13):** orforglipron half-life (48h) is an ESTIMATE — verify against the Foundayo label before shipping the graph; the UI already labels it "estimated". Existing installs get defaulted fields (Task 3) and are NOT re-onboarded (RootView keys off `onboardingComplete`).
- **Known pre-existing test:** headless StoreKit config case remains XCTSkip; the onboarding→paywall UI test is intentionally repurposed in Task 5; the stale trial assertion is fixed in Task 6.
- **Verify before coding:** `WeightEntry` init/property names (Task 10), whether a reusable weight-log screen already exists in Progress (Task 11), and that `LoadingSplashView` has no other references before deletion (Task 5).
