# GLPill v1.0 Pill-Native Ritual Upgrade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the daily pill ritual the hero of GLPill — a stateful Today card, a neutral morning-meds timing helper, first-run/input polish, streamlined messaging, and a 7-day trial on the monthly plan — without a rebuild and without crossing into medical advice.

**Architecture:** Extract the Today tab's top card into a `RitualCard` driven by a pure, derived `RitualState` (computed from existing signals — no new state persistence). Add one optional `morningMeds: [String]` field on `UserSettings`, surfaced in the ritual card's cleared state and the existing window-end notification. Everything else on the Today tab is unchanged.

**Tech Stack:** SwiftUI + SwiftData (iOS 17), XcodeGen (`xcodegen generate` before every build — `App/Sources` is a folder reference, so new files need a regen), XCTest (match the existing 13 test files — NOT Swift Testing), StoreKit 2.

**Conventions used throughout:**
- After creating any new `.swift` file, run `xcodegen generate` before building.
- Build/test the whole suite: `xcodebuild test -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
- Run one test class: append `-only-testing:GLPillTests/<ClassName>`
- Commits: git author is already the noreply email; no attribution trailer (matches existing history).

---

## File Structure

**New source files**
- `App/Sources/Core/Logic/MorningMeds.swift` — pure normalize (trim/dedupe/drop-blank) for the meds list.
- `App/Sources/Features/Today/RitualState.swift` — the derived state enum + `make(...)`.
- `App/Sources/Features/Today/RitualCard.swift` — SwiftUI card rendering each `RitualState`.
- `App/Sources/Features/Today/RitualExplainerView.swift` — neutral, cited "why the 30-min window" sheet.
- `App/Sources/Features/Settings/MorningMedsEditor.swift` — add/remove list, reached from Settings.

**New test files**
- `App/Tests/MorningMedsTests.swift`
- `App/Tests/RitualStateTests.swift`

**Modified**
- `App/Sources/Core/Models/UserSettings.swift` — `+ morningMeds`
- `App/Sources/Features/Onboarding/OnboardingStore.swift` — `+ morningMeds`, persist normalized
- `App/Sources/Features/Onboarding/OnboardingFlow.swift` — new `MorningMedsStep`, bump `totalSteps`
- `App/Sources/Features/Settings/SettingsView.swift` — "Morning routine" section
- `App/Sources/Core/Notifications/ReminderScheduler.swift` — meds-aware `scheduleEatTimer`
- `App/Tests/ReminderSchedulerTests.swift` — meds-body cases
- `App/Sources/Features/Today/TodayView.swift` — use `RitualCard`; drop separate `EatTimerView` card
- `App/Sources/Features/Progress/ProgressScreen.swift` — baseline-weight empty-state
- `App/Tests/OnboardingStoreTests.swift` / `App/Tests/UnitFormatTests.swift` — input boundary tests
- `App/Sources/Features/Paywall/PaywallView.swift` + `OnboardingFlow.swift` WelcomeStep — messaging
- `App/Resources/GLPill.storekit` — monthly 7-day intro offer
- `docs/APP_STORE.md` — note the monthly intro-offer ASC step

---

## Task 1: `morningMeds` normalization helper

**Files:**
- Create: `App/Sources/Core/Logic/MorningMeds.swift`
- Test: `App/Tests/MorningMedsTests.swift`

- [ ] **Step 1: Write the failing test**

Create `App/Tests/MorningMedsTests.swift`:

```swift
import XCTest
@testable import GLPill

final class MorningMedsTests: XCTestCase {
    func testTrimsDropsBlanksAndDedupesCaseInsensitively() {
        let input = ["  Thyroid ", "", "   ", "thyroid", "BP med", "BP med"]
        XCTAssertEqual(MorningMeds.normalize(input), ["Thyroid", "BP med"])
    }

    func testEmptyStaysEmpty() {
        XCTAssertEqual(MorningMeds.normalize([]), [])
        XCTAssertEqual(MorningMeds.normalize(["  ", ""]), [])
    }

    func testPreservesFirstSeenCasingAndOrder() {
        XCTAssertEqual(MorningMeds.normalize(["Levo", "aspirin", "LEVO"]), ["Levo", "aspirin"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GLPillTests/MorningMedsTests`
Expected: FAIL — "cannot find 'MorningMeds' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `App/Sources/Core/Logic/MorningMeds.swift`:

```swift
import Foundation

/// Pure helpers for the user's optional "other morning meds" list (names only).
/// No dosages, no times, no interaction data — this is timing/reminder metadata,
/// not medical advice.
enum MorningMeds {
    /// Trim whitespace, drop blanks, and dedupe case-insensitively while
    /// preserving first-seen casing and order.
    static func normalize(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in raw {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed.lowercased()).inserted {
                result.append(trimmed)
            }
        }
        return result
    }
}
```

- [ ] **Step 4: Regenerate project and run test to verify it passes**

Run: `xcodegen generate && xcodebuild test -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GLPillTests/MorningMedsTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Core/Logic/MorningMeds.swift App/Tests/MorningMedsTests.swift
git commit -m "feat: MorningMeds.normalize helper (trim/dedupe/drop-blank)"
```

---

## Task 2: Persist `morningMeds` on `UserSettings` + `OnboardingStore`

**Files:**
- Modify: `App/Sources/Core/Models/UserSettings.swift`
- Modify: `App/Sources/Features/Onboarding/OnboardingStore.swift:33` (add property) and `:60-68` (pass into UserSettings)
- Test: `App/Tests/OnboardingStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `App/Tests/OnboardingStoreTests.swift` (inside the existing `final class OnboardingStoreTests: XCTestCase`; it already builds an in-memory `ModelContext` — reuse that pattern from the file's existing tests):

```swift
    func testCompletePersistsNormalizedMorningMeds() throws {
        let context = try makeContext()          // existing helper in this test file
        let store = OnboardingStore()
        store.kind = .rybelsus
        store.displayWeight = 180
        store.morningMeds = ["  Thyroid ", "thyroid", ""]

        try store.complete(in: context)

        let settings = try context.fetch(FetchDescriptor<UserSettings>()).first
        XCTAssertEqual(settings?.morningMeds, ["Thyroid"])
    }
```

> If `OnboardingStoreTests` has no `makeContext()` helper, use the same in-memory container setup the other tests in that file already use (look at the top of the file) and adapt this test to it.

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test ... -only-testing:GLPillTests/OnboardingStoreTests/testCompletePersistsNormalizedMorningMeds`
Expected: FAIL — `value of type 'OnboardingStore' has no member 'morningMeds'`.

- [ ] **Step 3: Write minimal implementation**

In `App/Sources/Core/Models/UserSettings.swift`, add the stored property after `lastCelebratedMilestone` (line 20) and the init param + assignment:

```swift
    /// Optional list of the user's OTHER morning medications (names only). Used to
    /// tell them when their empty-stomach window is clear. Timing metadata, not advice.
    var morningMeds: [String] = []
```

Add to the `init` signature (after `lastCelebratedMilestone: Int = 0`):

```swift
        morningMeds: [String] = [],
```

And in the init body:

```swift
        self.morningMeds = morningMeds
```

In `App/Sources/Features/Onboarding/OnboardingStore.swift`, add the property after `displayGoal` (line 34):

```swift
    var morningMeds: [String] = []
```

In `complete(in:now:)`, change the `UserSettings(...)` insert (lines 60-68) to pass normalized meds:

```swift
        context.insert(UserSettings(
            onboardingComplete: true,
            usesMetric: usesMetric,
            goalKilograms: goalKg,
            startKilograms: startKg,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            startDate: now,
            morningMeds: MorningMeds.normalize(morningMeds)
        ))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test ... -only-testing:GLPillTests/OnboardingStoreTests`
Expected: PASS (new test + existing onboarding tests still green).

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Core/Models/UserSettings.swift App/Sources/Features/Onboarding/OnboardingStore.swift App/Tests/OnboardingStoreTests.swift
git commit -m "feat: persist optional morningMeds through onboarding"
```

---

## Task 3: `RitualState` derived state machine

**Files:**
- Create: `App/Sources/Features/Today/RitualState.swift`
- Test: `App/Tests/RitualStateTests.swift`

- [ ] **Step 1: Write the failing test**

Create `App/Tests/RitualStateTests.swift`:

```swift
import XCTest
@testable import GLPill

final class RitualStateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private var later: Date { now.addingTimeInterval(600) }   // +10 min

    func testNotLoggedRybelsus() {
        let s = RitualState.make(todayLogged: false, requiresEmptyStomach: true,
                                 windowEnd: nil, meds: [], now: now)
        XCTAssertEqual(s, .notTaken(requiresEmptyStomach: true))
    }

    func testNotLoggedOrforglipron() {
        let s = RitualState.make(todayLogged: false, requiresEmptyStomach: false,
                                 windowEnd: nil, meds: [], now: now)
        XCTAssertEqual(s, .notTaken(requiresEmptyStomach: false))
    }

    func testLoggedOrforglipronIsClearNoWindow() {
        let s = RitualState.make(todayLogged: true, requiresEmptyStomach: false,
                                 windowEnd: nil, meds: ["Thyroid"], now: now)
        XCTAssertEqual(s, .clear(meds: ["Thyroid"], hadWindow: false))
    }

    func testLoggedRybelsusBeforeWindowEndIsRunning() {
        let s = RitualState.make(todayLogged: true, requiresEmptyStomach: true,
                                 windowEnd: later, meds: ["Thyroid"], now: now)
        XCTAssertEqual(s, .windowRunning(end: later, meds: ["Thyroid"]))
    }

    func testLoggedRybelsusAtWindowEndIsClear() {
        let s = RitualState.make(todayLogged: true, requiresEmptyStomach: true,
                                 windowEnd: now, meds: [], now: now)
        XCTAssertEqual(s, .clear(meds: [], hadWindow: true))
    }

    func testLoggedRybelsusAfterWindowEndIsClear() {
        let s = RitualState.make(todayLogged: true, requiresEmptyStomach: true,
                                 windowEnd: now, meds: [], now: later)
        XCTAssertEqual(s, .clear(meds: [], hadWindow: true))
    }

    func testLoggedRybelsusWithNoWindowEndFallsBackToClear() {
        let s = RitualState.make(todayLogged: true, requiresEmptyStomach: true,
                                 windowEnd: nil, meds: [], now: now)
        XCTAssertEqual(s, .clear(meds: [], hadWindow: false))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test ... -only-testing:GLPillTests/RitualStateTests`
Expected: FAIL — "cannot find 'RitualState' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `App/Sources/Features/Today/RitualState.swift`:

```swift
import Foundation

/// The Today tab's hero ("morning ritual") state, derived purely from existing
/// signals — never persisted. Rybelsus (empty stomach) runs a 30-min window;
/// orforglipron/Foundayo has no window.
enum RitualState: Equatable {
    /// No dose logged today. `requiresEmptyStomach` drives the reminder subline.
    case notTaken(requiresEmptyStomach: Bool)
    /// Dose logged, empty-stomach window still counting down.
    case windowRunning(end: Date, meds: [String])
    /// Dose logged and clear to eat: window elapsed (`hadWindow: true`) or the
    /// pill never had a window (`hadWindow: false`).
    case clear(meds: [String], hadWindow: Bool)

    static func make(
        todayLogged: Bool,
        requiresEmptyStomach: Bool,
        windowEnd: Date?,
        meds: [String],
        now: Date
    ) -> RitualState {
        guard todayLogged else {
            return .notTaken(requiresEmptyStomach: requiresEmptyStomach)
        }
        guard requiresEmptyStomach, let end = windowEnd else {
            return .clear(meds: meds, hadWindow: false)
        }
        return now < end ? .windowRunning(end: end, meds: meds)
                         : .clear(meds: meds, hadWindow: true)
    }
}
```

- [ ] **Step 4: Regenerate and run test to verify it passes**

Run: `xcodegen generate && xcodebuild test ... -only-testing:GLPillTests/RitualStateTests`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Features/Today/RitualState.swift App/Tests/RitualStateTests.swift
git commit -m "feat: RitualState derived state machine (Rybelsus vs orforglipron)"
```

---

## Task 4: Meds-aware eat-timer notification

**Files:**
- Modify: `App/Sources/Core/Notifications/ReminderScheduler.swift:29-36`
- Test: `App/Tests/ReminderSchedulerTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `App/Tests/ReminderSchedulerTests.swift`:

```swift
    func testEatTimerBodyGenericWhenNoMeds() {
        XCTAssertEqual(ReminderScheduler.eatTimerBody(meds: []),
                       "30 minutes are up — enjoy your meal.")
    }

    func testEatTimerBodyMentionsMedsWhenPresent() {
        XCTAssertEqual(ReminderScheduler.eatTimerBody(meds: ["Thyroid", "BP med"]),
                       "30 minutes are up — enjoy your meal. You can also take your Thyroid, BP med now.")
    }

    func testEatTimerPassesMedsBodyToScheduler() {
        let spy = SpyScheduler()
        ReminderScheduler.scheduleEatTimer(using: spy, meds: ["Thyroid"])
        XCTAssertEqual(spy.added.first?.body,
                       "30 minutes are up — enjoy your meal. You can also take your Thyroid now.")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test ... -only-testing:GLPillTests/ReminderSchedulerTests`
Expected: FAIL — no `eatTimerBody`; `scheduleEatTimer` has no `meds:` label.

- [ ] **Step 3: Write minimal implementation**

Replace `scheduleEatTimer` in `App/Sources/Core/Notifications/ReminderScheduler.swift` (lines 29-36) with:

```swift
    static func eatTimerBody(meds: [String]) -> String {
        let base = "30 minutes are up — enjoy your meal."
        guard !meds.isEmpty else { return base }
        return base + " You can also take your \(meds.joined(separator: ", ")) now."
    }

    static func scheduleEatTimer(using scheduler: NotificationScheduling, meds: [String] = []) {
        scheduler.add(
            id: eatTimerId,
            title: "You can eat now ✅",
            body: eatTimerBody(meds: meds),
            trigger: .once(after: 30 * 60)
        )
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test ... -only-testing:GLPillTests/ReminderSchedulerTests`
Expected: PASS (existing 2 + new 3). The default `meds: []` keeps existing callers compiling.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Core/Notifications/ReminderScheduler.swift App/Tests/ReminderSchedulerTests.swift
git commit -m "feat: eat-timer notification names the user's other morning meds"
```

---

## Task 5: `RitualExplainerView` (neutral, cited)

**Files:**
- Create: `App/Sources/Features/Today/RitualExplainerView.swift`

No unit test (pure static SwiftUI). Verified by build.

- [ ] **Step 1: Create the view**

Create `App/Sources/Features/Today/RitualExplainerView.swift`:

```swift
import SwiftUI

/// Neutral, source-cited explainer for the Rybelsus empty-stomach window.
/// Educational only — no advice, no per-drug interaction claims.
struct RitualExplainerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Why the 30-minute window?")
                        .font(.title2.bold())

                    Text("Oral semaglutide (Rybelsus®) is absorbed best on an empty stomach. The FDA label says to take it with a sip of plain water and then wait at least 30 minutes before eating, drinking anything else, or taking other oral medications.")
                        .font(.body)

                    Text("That's why GLPill starts a 30-minute countdown the moment you log your pill, and tells you when the window is clear — including when you can take your other morning meds.")
                        .font(.body)

                    Text("GLPill is a tracking tool, not medical advice. Always follow your prescriber's instructions and the timing your own doctor gives you.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Source: Rybelsus® Prescribing Information (FDA, via DailyMed).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Regenerate and build**

Run: `xcodegen generate && xcodebuild build -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add App/Sources/Features/Today/RitualExplainerView.swift
git commit -m "feat: neutral cited explainer for the empty-stomach window"
```

---

## Task 6: `RitualCard` view

**Files:**
- Create: `App/Sources/Features/Today/RitualCard.swift`

Renders each `RitualState`. Reuses `Card`, `PillCTAButton`, `EatTimerView`, `Theme`. No unit test (SwiftUI); the logic it depends on is already tested in Task 3.

- [ ] **Step 1: Create the view**

Create `App/Sources/Features/Today/RitualCard.swift`:

```swift
import SwiftUI

/// The Today tab's hero. Renders the pill ritual for the current `RitualState`.
struct RitualCard: View {
    let medName: String
    let doseSubtitle: String
    let state: RitualState
    let takePill: () -> Void
    @State private var showExplainer = false

    var body: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(medName).font(.headline)
                    Text(doseSubtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }

            switch state {
            case let .notTaken(requiresEmptyStomach):
                if requiresEmptyStomach {
                    HStack(spacing: 6) {
                        Text("Empty stomach · plain water · then wait 30 min")
                            .font(.caption).foregroundStyle(.secondary)
                        Button { showExplainer = true } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel("Why the 30-minute window?")
                    }
                } else {
                    Text("No timing rules — take it with or without food.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                PillCTAButton(title: "Take today's pill", systemImage: "pills.fill", action: takePill)

            case let .windowRunning(end, meds):
                EatTimerView(end: end)
                if !meds.isEmpty {
                    Label("Other morning meds — after \(end.formatted(date: .omitted, time: .shortened))",
                          systemImage: "clock.badge.checkmark")
                        .font(.caption).foregroundStyle(.secondary)
                }

            case let .clear(meds, hadWindow):
                Label(hadWindow ? "You're clear — you can eat now" : "Logged for today ✓",
                      systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                if !meds.isEmpty {
                    Text(hadWindow
                         ? "You can take your \(meds.joined(separator: ", ")) now."
                         : "You can take your \(meds.joined(separator: ", ")) any time.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showExplainer) { RitualExplainerView() }
    }
}
```

- [ ] **Step 2: Regenerate and build**

Run: `xcodegen generate && xcodebuild build -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add App/Sources/Features/Today/RitualCard.swift
git commit -m "feat: RitualCard hero rendering each ritual state"
```

---

## Task 7: Wire `RitualCard` into `TodayView`

**Files:**
- Modify: `App/Sources/Features/Today/TodayView.swift` (replace `doseCard` usage + the separate `EatTimerView` card; update `takePill`)

- [ ] **Step 1: Replace the top of the Today body**

In `TodayView.body`, the `ScrollView`'s `VStack` currently is:

```swift
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        ...
                    doseCard
                    if eatTimerActive {
                        EatTimerView(end: Date(timeIntervalSince1970: eatTimerEnd))
                    }
                    streakCard
```

Replace `doseCard` + the `if eatTimerActive { EatTimerView(...) }` block with a single `ritualCard`:

```swift
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ritualCard
                    streakCard
```

- [ ] **Step 2: Add the `ritualCard` computed property and delete `doseCard`**

Delete the existing `private var doseCard: some View { ... }` block. Add:

```swift
    private var ritualState: RitualState {
        RitualState.make(
            todayLogged: todayLog != nil,
            requiresEmptyStomach: medications.first?.requiresEmptyStomach ?? false,
            windowEnd: eatTimerEnd > 0 ? Date(timeIntervalSince1970: eatTimerEnd) : nil,
            meds: settingsList.first?.morningMeds ?? [],
            now: .now
        )
    }

    private var ritualCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            RitualCard(
                medName: medications.first?.displayName ?? "Your GLP-1 pill",
                doseSubtitle: doseSubtitle,
                state: ritualState,
                takePill: takePill
            )
        }
    }
```

> The `TimelineView` wrapper re-evaluates `ritualState` every second so it flips `windowRunning → clear` at the window end without extra state. `doseSubtitle` (the existing computed property) stays. `eatTimerActive` is now unused — delete that computed property to avoid a dead-code warning.

- [ ] **Step 3: Make `takePill` schedule the meds-aware notification**

In `takePill()`, change the timer-scheduling line to pass the user's meds:

```swift
            if startTimer {
                eatTimerEnd = Date().addingTimeInterval(30 * 60).timeIntervalSince1970
                ReminderScheduler.scheduleEatTimer(
                    using: UNNotificationScheduler(),
                    meds: settingsList.first?.morningMeds ?? []
                )
            }
```

- [ ] **Step 4: Build and run the full suite**

Run: `xcodegen generate && xcodebuild test -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: BUILD SUCCEEDED, all tests PASS (existing 57 + new). No "unused `eatTimerActive`" warning.

- [ ] **Step 5: Manual smoke (simulator)**

Run the app with `-uiTestUnlocked -disableCloudKit`. On the Today tab: before logging → "Take today's pill" + subline; tap it (Rybelsus) → countdown becomes hero; wait/advance → "You're clear". Confirm streak/protein/water still render below.

- [ ] **Step 6: Commit**

```bash
git add App/Sources/Features/Today/TodayView.swift
git commit -m "feat: Today tab uses the RitualCard hero (timer folded in)"
```

---

## Task 8: Morning-meds capture in onboarding

**Files:**
- Modify: `App/Sources/Features/Onboarding/OnboardingFlow.swift` (`totalSteps`, step switch, new `MorningMedsStep`)

- [ ] **Step 1: Bump step count and insert the step**

In `OnboardingFlow`, change `private let totalSteps = 5` to `= 6`. Update the `switch step` so the new step is 4 and Reminder becomes 5:

```swift
            switch step {
            case 0: WelcomeStep(next: advance)
            case 1: MedicationStep(store: store, next: advance)
            case 2: TitrationSetupStep(store: store, next: advance)
            case 3: WeightStep(store: store, next: advance)
            case 4: MorningMedsStep(store: store, next: advance)
            default: ReminderStep(store: store, finish: complete)
            }
```

- [ ] **Step 2: Add the `MorningMedsStep` view**

Add this private view to `OnboardingFlow.swift` (after `WeightStep`):

```swift
private struct MorningMedsStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    @State private var entry = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Other morning meds?")
                .font(.title.bold())
                .padding(.top, 24)
            Text("Optional. Add anything else you take in the morning (thyroid, blood pressure, birth control). We'll tell you when your empty-stomach window is clear so you know when to take them. Names only — stored privately on your device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Add a medication", text: $entry)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Add", action: add)
                    .buttonStyle(.bordered)
                    .disabled(entry.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            ForEach(store.morningMeds, id: \.self) { med in
                HStack {
                    Text(med)
                    Spacer()
                    Button {
                        store.morningMeds.removeAll { $0 == med }
                    } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.secondary) }
                }
            }

            Spacer()
            PillCTAButton(title: store.morningMeds.isEmpty ? "Skip for now" : "Continue",
                          systemImage: "arrow.right") { next() }
                .padding(.bottom, 24)
        }
        .padding(.horizontal)
        .background(Color(.systemGroupedBackground))
    }

    private func add() {
        store.morningMeds = MorningMeds.normalize(store.morningMeds + [entry])
        entry = ""
    }
}
```

- [ ] **Step 3: Regenerate, build, and smoke-test**

Run: `xcodegen generate && xcodebuild build -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: BUILD SUCCEEDED. Run onboarding in the sim: the meds step adds/removes/dedupes and the button reads "Skip for now" when empty.

- [ ] **Step 4: Commit**

```bash
git add App/Sources/Features/Onboarding/OnboardingFlow.swift
git commit -m "feat: optional morning-meds step in onboarding"
```

---

## Task 9: Morning-meds editing in Settings

**Files:**
- Create: `App/Sources/Features/Settings/MorningMedsEditor.swift`
- Modify: `App/Sources/Features/Settings/SettingsView.swift` (add a navigation row)

- [ ] **Step 1: Create the editor**

Create `App/Sources/Features/Settings/MorningMedsEditor.swift`:

```swift
import SwiftUI
import SwiftData

struct MorningMedsEditor: View {
    @Query private var settingsList: [UserSettings]
    @State private var entry = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Add a medication", text: $entry)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(entry.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("Names only. We use these to tell you when your empty-stomach window is clear. Stored privately on your device.")
            }

            if let settings = settingsList.first, !settings.morningMeds.isEmpty {
                Section {
                    ForEach(settings.morningMeds, id: \.self) { med in
                        Text(med)
                    }
                    .onDelete { offsets in
                        var meds = settings.morningMeds
                        meds.remove(atOffsets: offsets)
                        settings.morningMeds = meds
                    }
                }
            }
        }
        .navigationTitle("Morning meds")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add() {
        guard let settings = settingsList.first else { return }
        settings.morningMeds = MorningMeds.normalize(settings.morningMeds + [entry])
        entry = ""
    }
}
```

- [ ] **Step 2: Add the Settings row**

In `SettingsView.swift`, add a row inside the existing `Section("Medication")` (after the "Dose plan" `NavigationLink`, before the section closes at line 21):

```swift
                    NavigationLink("Morning meds") {
                        MorningMedsEditor()
                    }
```

- [ ] **Step 3: Regenerate, build, smoke-test**

Run: `xcodegen generate && xcodebuild build ...`
Expected: BUILD SUCCEEDED. In Settings → Medication → Morning meds: add/delete works and persists.

- [ ] **Step 4: Commit**

```bash
git add App/Sources/Features/Settings/MorningMedsEditor.swift App/Sources/Features/Settings/SettingsView.swift
git commit -m "feat: edit morning meds from Settings"
```

---

## Task 10: Baseline-weight empty-state nudge

**Files:**
- Modify: `App/Sources/Features/Progress/ProgressScreen.swift` (the `statsCard`/`chartCard` empty path)

The chart already handles `< 2` entries, but the stats card shows bare "—" when there are zero entries. Add a clear nudge above the stats when there is **no** weight logged yet.

- [ ] **Step 1: Add a nudge card and show it when empty**

In `ProgressScreen.swift`, add this computed view:

```swift
    private var baselineNudge: some View {
        Card {
            SectionHeader(title: "Start tracking your progress")
            Text("Add your starting weight so GLPill can show your trend, total change, and milestones.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showEntrySheet = true
            } label: {
                Label("Add starting weight", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(Theme.primary)
        }
    }
```

In the body `VStack`, show it only when there are no entries — change:

```swift
                VStack(spacing: 16) {
                    monthCard
                    statsCard
                    chartCard
                    shareCard
                }
```

to:

```swift
                VStack(spacing: 16) {
                    monthCard
                    if entries.isEmpty {
                        baselineNudge
                    } else {
                        statsCard
                    }
                    chartCard
                    shareCard
                }
```

- [ ] **Step 2: Build and smoke-test**

Run: `xcodegen generate && xcodebuild build ...`
Expected: BUILD SUCCEEDED. Fresh account (skip weight) → Progress shows the "Add starting weight" nudge instead of "—"; after adding one weigh-in, the stats card returns.

- [ ] **Step 3: Commit**

```bash
git add App/Sources/Features/Progress/ProgressScreen.swift
git commit -m "feat: nudge for a starting weight instead of a bare em dash"
```

---

## Task 11: Input boundary tests (lock in existing validation)

**Files:**
- Modify: `App/Tests/UnitFormatTests.swift`

Validation already exists (`isValidWeight` 25–500 kg, `isValidDose`). Add explicit boundary tests so regressions are caught; no production change expected.

- [ ] **Step 1: Write the tests**

Add to `App/Tests/UnitFormatTests.swift`:

```swift
    func testValidWeightBoundaries() {
        XCTAssertFalse(UnitFormat.isValidWeight(kilograms: 0))
        XCTAssertFalse(UnitFormat.isValidWeight(kilograms: 24.9))
        XCTAssertTrue(UnitFormat.isValidWeight(kilograms: 25))
        XCTAssertTrue(UnitFormat.isValidWeight(kilograms: 500))
        XCTAssertFalse(UnitFormat.isValidWeight(kilograms: 500.1))
        XCTAssertFalse(UnitFormat.isValidWeight(kilograms: -70))
    }

    func testValidDoseBoundaries() {
        XCTAssertFalse(UnitFormat.isValidDose(mg: 0))
        XCTAssertFalse(UnitFormat.isValidDose(mg: 0.04))
        XCTAssertTrue(UnitFormat.isValidDose(mg: 0.05))
        XCTAssertTrue(UnitFormat.isValidDose(mg: 50))
        XCTAssertFalse(UnitFormat.isValidDose(mg: 50.1))
    }
```

> If a boundary assertion fails, the production bound is wrong — fix `UnitFormat.isValidWeight`/`isValidDose` in `App/Sources/Core/Logic/UnitFormat.swift` to match (25...500 kg, 0.05...50 mg), then re-run.

- [ ] **Step 2: Run to verify pass (validation already present)**

Run: `xcodebuild test ... -only-testing:GLPillTests/UnitFormatTests`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add App/Tests/UnitFormatTests.swift
git commit -m "test: lock in weight/dose validation boundaries"
```

---

## Task 12: Streamlined messaging (paywall + welcome)

**Files:**
- Modify: `App/Sources/Features/Paywall/PaywallView.swift` (hero + bullet order)
- Modify: `App/Sources/Features/Onboarding/OnboardingFlow.swift` (`WelcomeStep` copy)

- [ ] **Step 1: Reframe the paywall hero + bullets**

In `PaywallView.swift`, update the hero title and lead bullets so the ritual leads. Set the hero headline to **"Never mistime your pill again"** and reorder the feature bullets to this order (keep the existing bullet component/style; only change text + order):

```
1. clock.fill        — "Time the empty-stomach window"  — "Log your pill and we count the 30 minutes; we tell you the exact minute you can eat and take your other morning meds."
2. pills.fill        — "Never miss a dose"               — "One-tap logging, streaks and a daily reminder."
3. icloud.fill       — "Never lose your history"         — "Syncs privately across your devices."
4. chart.line.uptrend.xyaxis — "Watch it work"           — "Weight trend, milestones and share-ready cards."
5. doc.text.fill     — "Doctor-ready reports"            — "Adherence, doses and side effects in one summary."
```

> Match the existing bullet-rendering code in `PaywallView` — change only the strings and their order; do not restructure the view.

- [ ] **Step 2: Align the onboarding welcome copy**

In `OnboardingFlow.swift` `WelcomeStep`, change the subtitle (line 75) to lead with the ritual:

```swift
            Text("The app built for the GLP-1 pill — Foundayo®, Rybelsus® and daily oral GLP-1s. We time your empty-stomach window; injections had their apps, your pill gets one too.")
```

- [ ] **Step 3: Build and visually check**

Run: `xcodegen generate && xcodebuild build ...`
Expected: BUILD SUCCEEDED. Launch → onboarding welcome + paywall lead with the ritual.

- [ ] **Step 4: Commit**

```bash
git add App/Sources/Features/Paywall/PaywallView.swift App/Sources/Features/Onboarding/OnboardingFlow.swift
git commit -m "copy: lead messaging with the pill ritual"
```

---

## Task 13: 7-day trial on the monthly plan

**Files:**
- Modify: `App/Resources/GLPill.storekit` (add monthly intro offer)
- Modify: `App/Tests/StoreKitConfigTests.swift` (assert both plans have a 7-day free intro offer)
- Modify: `docs/APP_STORE.md` (note the ASC step)

- [ ] **Step 1: Write the failing test**

First inspect `App/Tests/StoreKitConfigTests.swift` to match its style (it parses `GLPill.storekit`). Add a test asserting the **monthly** product has a `P7D` free introductory offer (mirror whatever assertion it already makes for the yearly plan). Example shape:

```swift
    func testMonthlyHasSevenDayFreeTrial() throws {
        let config = try loadStoreKitConfig()          // existing helper in this file
        let monthly = config.subscription(withProductID: "glpill.pro.monthly")
        XCTAssertEqual(monthly?.introductoryOffer?.paymentMode, "free")
        XCTAssertEqual(monthly?.introductoryOffer?.subscriptionPeriod, "P7D")
    }
```

> Adapt to the actual parsing helpers in `StoreKitConfigTests.swift`. If it currently only checks the yearly plan, copy that assertion and point it at `glpill.pro.monthly`.

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test ... -only-testing:GLPillTests/StoreKitConfigTests`
Expected: FAIL — monthly `introductoryOffer` is `null`.

- [ ] **Step 3: Add the intro offer to the monthly product**

In `App/Resources/GLPill.storekit`, the monthly subscription (`"productID" : "glpill.pro.monthly"`) currently has `"introductoryOffer" : null`. Replace that with (mirroring the yearly plan's offer, unique `internalID`):

```json
          "introductoryOffer" : {
            "internalID" : "1000000004",
            "numberOfPeriods" : 1,
            "paymentMode" : "free",
            "subscriptionPeriod" : "P7D"
          },
```

- [ ] **Step 4: Run to verify it passes**

Run: `xcodebuild test ... -only-testing:GLPillTests/StoreKitConfigTests`
Expected: PASS.

- [ ] **Step 5: Update the paywall copy for the monthly trial**

In `PaywallView.swift`, wherever the monthly plan card renders its subtitle, surface the trial (mirror the yearly "7-DAY FREE TRIAL" treatment). Show both plans offering a 7-day free trial. Keep the existing plan-card component; change only copy.

- [ ] **Step 6: Document the ASC step**

In `docs/APP_STORE.md`, under the subscription setup section, add:

```
- glpill.pro.monthly ALSO gets a 7-day free introductory offer — configure it in App Store Connect (Subscriptions → Pro Monthly → Subscription Prices → Introductory Offer: Free, 1 week) before submitting.
```

- [ ] **Step 7: Build + full suite + commit**

Run: `xcodegen generate && xcodebuild test -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: all tests PASS.

```bash
git add App/Resources/GLPill.storekit App/Tests/StoreKitConfigTests.swift App/Sources/Features/Paywall/PaywallView.swift docs/APP_STORE.md
git commit -m "feat: 7-day free trial on the monthly plan too"
```

---

## Task 14: Final verification

- [ ] **Step 1: Full suite green**

Run: `xcodegen generate && xcodebuild test -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: BUILD SUCCEEDED; all tests pass (existing 57 + the new MorningMeds/RitualState/ReminderScheduler/OnboardingStore/UnitFormat/StoreKitConfig additions).

- [ ] **Step 2: End-to-end simulator smoke (`-uiTestUnlocked -disableCloudKit`)**

- Onboarding: pick Rybelsus, add a morning med, finish.
- Today: "Take today's pill" → countdown hero → other-meds "after HH:MM" → at window end, "You're clear" + "take your [med] now".
- Repeat with Foundayo/orforglipron: no timer, "Logged for today ✓" + "any time" meds copy.
- Progress with no weight → nudge; add a weigh-in → stats return.
- Paywall + welcome lead with the ritual; both plans show a 7-day trial.

- [ ] **Step 3: Finish the branch**

Use superpowers:finishing-a-development-branch to verify tests, then merge/PR per the user's choice.

---

## Notes for the executor

- **Do not** add per-drug interaction logic, warnings, or advice anywhere — the morning-meds feature is timing/reminder only. This preserves the "not medical advice" posture and the 12+ age rating.
- **Do not** add analytics, network calls, or new data collection — App Privacy stays "Data Not Collected".
- Keep new files small and single-purpose; follow the existing `Card`/`PillCTAButton`/`Theme` patterns.
- If any SwiftUI wiring detail differs from what's written here (e.g., a bullet component signature in `PaywallView`), match the file's actual pattern — the copy/behavior is what matters.
