# GLPill P1 UX Follow-up — Implementation Plan

> Built on branch `feat/ux-p1-followup` (worktree, off `main`). TDD for logic; SwiftUI views get build + walkthrough verification. Source audit: `docs/qa/2026-07-21-ux-audit.md`.

**Goal:** Ship the three highest-leverage P1 themes from the UX audit: (1) doctor-report missed-dose signal, (2) accessibility pack, (3) milestone/Wrapped delight.

**Conventions:** `xcodegen generate` from the **worktree root** (`/Users/gupta/Downloads/Development/Projects/glpill-ux-p1`) after adding files; build/test `xcodebuild -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`; use `-only-testing:` (the known `StoreKitConfigTests.testPurchaseYearlyUnlocksEntitlement` headless crash hangs a full run — ignore it). Commit per group; no attribution footer. Constraints intact (timing/education only, non-shaming, Data Not Collected).

**Current-state notes (already done — do NOT redo):** the report adherence line already reads "Adherence: X% (D of W days)" (`ReportComposer.adherenceLine`). History already has `accessibilityLabel` per day and a side-effect `Circle()` indicator. Build on these.

---

## GROUP 1 — Doctor-report missed-dose signal

**Files:** new `App/Sources/Core/Logic/AdherenceStats.swift` (pure, TDD); `App/Sources/Core/Logic/ReportComposer.swift`; `App/Sources/Features/History/HistoryView.swift`.

1. **`AdherenceStats.longestGapDays(doseDays:from:to:calendar:) -> Int`** — the longest run of consecutive *expected-but-missed* days in `[from, to]` (a day is "expected" from the plan start through today; missed = not in `doseDays`). TDD: no gaps → 0; a 3-day hole → 3; all missed → window length; trailing/leading gaps counted.
2. **Report "Longest gap" line** — append to `ReportComposer` after the adherence line: `"Longest gap: N days"` (omit or say "none" when 0). A clinician needs 75%-even vs 75%-with-a-week-hole to differ.
3. **History missed-day ring** — in `HistoryView.dayCell`, for a **past, non-future, expected** day that is NOT dosed, render a **hollow outlined ring** (`Circle().stroke(Color.secondary.opacity(0.4))`) so a gap reads as a gap rather than a blank cell. Do not mark future days. Update the day's `accessibilityLabel` to say "missed" for those.

Commit: `feat: report longest-gap + History missed-day rings`

## GROUP 2 — Accessibility pack

**Files:** `App/Sources/Features/Today/MedicationLevelView.swift`, `App/Sources/Features/Progress/ProgressScreen.swift`, `App/Sources/Features/History/HistoryView.swift`, `App/Sources/Features/Progress/ShareCardView.swift` + `App/Sources/Features/Recap/WrappedCardView.swift`/`TrophyCardView.swift`.

1. **VoiceOver for charts** — the weight chart (`ProgressScreen`) and `MedicationLevelView` are opaque to VoiceOver. Add a concise text alternative via `.accessibilityLabel` on the `Chart` summarizing trend + endpoints (e.g. "Weight trend, 82 kg to 79 kg over 30 days" / "Estimated medication level, building toward steady state"), and `.accessibilityElement(children: .ignore)` so VoiceOver reads the summary, not the bars. (An `AXChartDescriptor` is nicer but the summary label is the pragmatic must-have.)
2. **History colorblind glyph** — dosed days currently differ by a filled `Theme.primary` circle (color-heavy). Add a small `checkmark` glyph (or bold ✓) inside dosed cells so dosed vs missed (hollow ring, Group 1) vs future differ by *shape*, not color alone.
3. **44pt tap targets** — `ProgressScreen` weigh-in delete is a bare ~20pt trash glyph; convert the row to `.swipeActions { Button(role:.destructive) }` (or pad the control to ≥44×44). Ensure History day cells are ≥44pt.
4. **Share/recap card a11y** — wrap `ShareCardView`, `WrappedCardView`, `TrophyCardView` content in `.accessibilityElement(children: .combine)` with a composed label so VoiceOver reads one coherent sentence, not fragments.

Commit: `feat: accessibility — chart VoiceOver, History glyphs, 44pt targets, combined cards`

## GROUP 3 — Milestone / Wrapped delight

**Files:** `App/Sources/Features/Recap/MilestoneCelebrationView.swift`, `TrophyCardView.swift`, `RecapView.swift`, `WrappedCardView.swift`. New `App/Sources/Features/Recap/ConfettiView.swift`.

1. **Tiered trophy** — `TrophyCardView`/milestone should vary by tier: 7 → 🌱 (or flame), 30 → 🔥, 100 → 🏆, 365 → 👑 with a gold ring. Add a pure `MilestoneTier.for(milestone:) -> (emoji:String, ringColor:Color, blurb:String)` helper (TDD the mapping).
2. **Animated reveal** (in-app `MilestoneCelebrationView`, NOT the exported card): count-up the streak number with `.contentTransition(.numericText())`, stagger-fade the stat pills (sequential `.opacity`/`.offset` with delays), and fire `.sensoryFeedback(.success, trigger:)` on appear.
3. **Confetti** — a lightweight SwiftUI `ConfettiView` (a `TimelineView`/`Canvas` or a set of animated colored capsules falling) that bursts on milestone reveal, intensity/particle-count scaled by tier. Pure-SwiftUI, no deps. Keep it off the **exported** share card (static).

Commit: `feat: milestone delight — tiered trophy, count-up, haptic, confetti`

---

## Verification
- Targeted unit suites green (`AdherenceStatsTests`, `MilestoneTierTests`).
- Build SUCCEEDED; extend/re-run the walkthrough to screenshot History (missed rings), the report, and a milestone celebration.
- VoiceOver spot-check note for the user (controller can't fully drive VoiceOver headless).

## Out of scope (later): retroactive "mark as taken", denied-notifications banner, in-app delete-all, History locale week-start bug, duplicate-date weigh-ins, report old-baseline fallback, MorningMeds id-keyed rows, titration date windows.
