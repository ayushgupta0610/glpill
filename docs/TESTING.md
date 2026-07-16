# GLPill — Testing Strategy

**Snapshot:** 58 unit tests across 13 files + 1 UI-test suite. Logic and data layers are covered by fast, deterministic unit tests; StoreKit purchase, CloudKit sync, push, and widget rendering are verified out-of-band (manual/device) because they can't run reliably headless. Target coverage: 80% of the logic layer.

## Philosophy

- **Test the logic, not the framework.** Pure functions and store mutations are unit-tested; SwiftUI views are not (they're thin and verified visually).
- **TDD-leaning for logic.** New logic (streaks, titration, stats, the widget snapshot) gets a failing test first, then the implementation.
- **Every change is verified before commit** with `xcodebuild test` — the build must be green and the suite must pass. No "it should work."
- **Deterministic.** Tests inject `Calendar`, dates, and providers — no reliance on wall-clock `.now` where a fixed date matters.

## How to run

```bash
xcodegen generate            # ALWAYS regenerate the project first (project.yml is source of truth)
xcodebuild test \
  -project GLPill.xcodeproj -scheme GLPill \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

Run one class: add `-only-testing:GLPillTests/StreakCalculatorTests`.

## The layers

### 1. Unit tests — `App/Tests/` (58 tests, 13 files)

| File | ~Tests | Covers |
|---|---|---|
| `StreakCalculatorTests` | 12 | Current/longest streak, adherence % — the core habit logic and the widget's number. |
| `TitrationProgressTests` | 6 | Dose-step position from plan start (which dose the user is on today). |
| `OnboardingStoreTests` | 6 | Onboarding write path, defaults, medication/plan setup. |
| `TodayStoreTests` | 5 | Dose logging (idempotent per day), protein/water/side-effect writes, **widget snapshot publish**. |
| `UnitFormatTests` | 5 | US units (lb/oz) formatting. |
| `ModelContainerTests` | 4 | SwiftData container creation (in-memory + fallback), wipe. |
| `ReportComposerTests` | 4 | Doctor-report summary (adherence, dose steps, weight change, side effects). |
| `WeightStatsTests` | 4 | Weight trend / change math. |
| `WidgetSnapshotTests` | 4 | Snapshot streak/taken-today logic + Codable round-trip + **end-to-end logDose→App Group→load**. |
| `SubscriptionGateTests` | 3 | Entitlement gating (locked vs unlocked routing) via a mock provider. |
| `ReminderSchedulerTests` | 2 | Notification scheduling requests (mocked notification center). |
| `StoreKitConfigTests` | 2 | Products load + purchase→entitlement (see caveat below). |
| `SmokeTests` | 1 | App boots / container builds. |

**Isolation:** store tests use an **in-memory** `ModelContainer` (`ModelContainerFactory.make(inMemory: true)`); gated-UI logic uses an injected `EntitlementProviding` mock (`AlwaysActiveProvider`, DEBUG-only). No shared mutable state between tests.

### 2. UI tests — `App/UITests/GLPillUITests.swift`

Critical-flow smoke via `XCUIApplication` launched with:
- `-uiTestUnlocked` → injects `AlwaysActiveProvider` so the hard paywall is bypassed (DEBUG only).
- `-resetData` → wipes the store for a clean run.

### 3. Manual / device verification (things that can't run headless)

| Area | How it's verified | Why not unit-tested |
|---|---|---|
| StoreKit purchase / trial | Run in Xcode with `App/Resources/GLPill.storekit` config → tap subscribe → StoreKit test purchase unlocks. | The headless test session serves no products (see caveat). |
| CloudKit private-DB sync | Physical device, signed with the paid team + iCloud account: log data, reinstall / new phone, confirm history returns. | CloudKit can't run on the simulator (entitlement not applied) and needs a real iCloud account. |
| Push / background sync | Physical device — near-real-time sync after `remote-notification` background mode. | Device-only; requires APNs + provisioned Push. |
| Widget rendering | Simulator or device: add "Pill Streak" from the widget gallery, confirm streak + status. | Visual; App Group works on simulator, real render needs the home screen. |

## Key gotchas baked into the setup

1. **`xcodegen generate` before every build.** `project.yml` is the source of truth; the `.xcodeproj` is generated and git-ignored.
2. **CloudKit is force-disabled on the simulator.** `ModelContainerFactory` uses `#if targetEnvironment(simulator)` to use a local store, and the test scheme also passes `-disableCloudKit`. Reason: iOS 26.5 **hard-traps** (`PFCloudKitContainerProvider` → `EXC_BREAKPOINT`) when CloudKit mirroring initializes without an applied entitlement (simulator / unsigned test host). Without this, the app crashes at launch on the simulator.
3. **StoreKit config tests self-skip headless.** `StoreKitConfigTests` wraps assertions in a retry + `XCTSkip("StoreKit test session served no products in this environment")` — so `xcodebuild test` reports 2 skipped, not failed. Verify purchases manually in Xcode instead.
4. **`CODE_SIGNING_ALLOWED=NO`** for simulator test/build runs — entitlements aren't enforced on the simulator, so signing isn't needed and would otherwise require the paid team.

## What "green" means before a commit

- `xcodebuild test` → `** TEST SUCCEEDED **`, `Executed 58 tests, 0 failures, 2 skipped`.
- No new compiler warnings introduced.
- For any new logic: a test that was written first and watched fail.

## Gaps / follow-ups

- Purchase-flow and restore-purchases are only manually verified — a StoreKit `Testing` session in a dedicated scheme could automate this later.
- No snapshot/visual-regression tests for SwiftUI (acceptable at this size; revisit if the UI churns).
- CloudKit conflict-resolution behavior is untested (SwiftData handles it; we'd only test if we saw real conflicts).
