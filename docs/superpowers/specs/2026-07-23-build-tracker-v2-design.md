# Build Tracker v2 — Journey-style Today / Progress / History

**Status:** Approved for planning
**Branch:** `feat/build-tracker-v2`

## Problem

GLPill's current Progress tab (`ProgressScreen.swift`) shows isolated values: current weight, total change, a line chart, a list of weigh-ins, a share card. It answers "what is my weight" but not "how am I doing on my journey" — no sense of pace, no milestones, no narrative of progress over time. That same isolation shows up elsewhere: Today never mentions the journey at all, and History (`HistoryView.swift`) tracks dose/side-effect days but has no notion of weigh-ins or milestones.

## Goal

Make the journey concept visible everywhere the user already looks, in the spirit of Apple Health / Flighty / Linear: minimal, calm, every number has historical context, nothing displayed in isolation. Reuse GLPill's existing visual language (`Theme.swift`, `Components.swift`) and existing data — no new backend, no new external dependencies.

Three surfaces change:

1. **Progress tab** — full journey redesign (the core of this spec).
2. **Today tab** — a compact journey snippet near the top (e.g. "Day 42 · 73% to goal · on pace"), so the momentum feeling is present daily, not just when the user opens Progress.
3. **History tab** — the existing month calendar grid gains weigh-in/milestone markers, and `DayDetailSheet` gains a "Weight" section alongside its existing Dose/Side effects/Intake sections.

## Non-goals (explicitly deferred)

- GitHub-style activity heatmap (History's existing month grid gets weigh-in/milestone markers, per below — a full heatmap is a separate build)
- Notes / daily journal
- Attachments (photos, links)
- Cross-entity relationships, full-text search
- User-authored milestones (v1 milestones are auto-generated only)
- Field-level change history ("old value → new value" audit log)
- Confidence-scored predictions (v1 prediction is simple linear trend, no confidence %)

## Data sources (all pre-existing, no schema changes to these)

- `WeightEntry` (`date`, `kilograms`) — one row per weigh-in
- `DoseLog` (`date`, `takenAt`, `doseMg`) — one row per dose
- `UserSettings` (`goalKilograms`, `startKilograms`, `startDate`, `usesMetric`, `lastCelebratedMilestone`) — canonical row via `UserSettings.canonical(in:)`
- `WeightStats.totalChange`, `WeightStats.toGoal`, `WeightStats.milestonesReached` (existing, in `Core/Logic/WeightStats.swift`)
- `StreakCalculator.currentStreak` (existing, in `Core/Logic/StreakCalculator.swift`)
- `UnitFormat.weightString` (existing, in `Core/Logic`)

## New code

No new SwiftData model. Milestones are computed on the fly from `WeightEntry` + `UserSettings.goalKilograms`, exactly like `WeightStats.milestonesReached` already partially does. This keeps v1 fully offline-computable and avoids a CloudKit schema migration.

New pure-logic types (in `Core/Logic/`, unit-testable, no SwiftUI/SwiftData dependency):

- `JourneyMilestone.swift` — struct `{ id, label, targetKg, reachedDate: Date? }`, plus `static func milestones(startKg:goalKg:entries:) -> [JourneyMilestone]` generating one milestone every 20% of the total start→goal distance (min 3, max 6 milestones), each stamped with the date it was first reached (first `WeightEntry` at or past that weight) or nil if not yet reached.
- `JourneyVelocity.swift` — struct `{ kgPerWeek: Double, projectedCompletion: Date? }`, computed via simple linear regression (or last-4-entries average slope, whichever the plan chooses) over `WeightEntry` sorted by date. Returns nil projection if fewer than 3 entries or slope is ~0/wrong direction.
- `JourneyInsight.swift` — struct `{ text: String }`, `static func insights(entries:goalKg:startDate:) -> [JourneyInsight]` producing 0–3 template-filled sentences from comparing this-month vs last-month velocity (e.g. "You're losing weight 20% faster than last month.", "Pace predicts your goal 9 days early."). Pure arithmetic, no ML. Returns `[]` gracefully with sparse data — never fabricates a claim it can't support.
- `ActivityEvent.swift` — struct `{ id, date, kind: .weighIn(kg) | .dose | .milestone(JourneyMilestone) }` plus a merge/sort function combining `WeightEntry` + `DoseLog` + reached `JourneyMilestone`s into one reverse-chronological feed.

New views (in `Features/Progress/`, replacing content of `ProgressScreen.swift`; file split for size per house style):

- `ProgressScreen.swift` — top-level layout, orchestration (kept, restructured)
- `JourneyHeaderView.swift` — title, current stage label, days since start, completion %
- `JourneyProgressCard.swift` — progress ring, current weight with `▲/▼ since last week` / `since start` deltas, velocity, projected completion, streak (reuses `StatBadge`, `Card`)
- `JourneyTimelineView.swift` — horizontal `ScrollView` of milestone chips (start → milestones → today marker → projected goal), tappable to reveal date/weight
- `ActivityFeedView.swift` — reverse-chron list of `ActivityEvent`, GitHub-style row styling
- `JourneyInsightsCard.swift` — renders `JourneyInsight.insights(...)`, hidden entirely if empty (no empty-insight placeholder card)

Existing pieces carried over unchanged into the new layout: `chartCard` logic, weigh-in edit/delete list, `shareCard`/`ShareCardView`, `WeightEntrySheet`, `baselineNudge` empty state, `monthCard` (My Month → Recap) — folded into the new `ProgressScreen` body rather than rewritten.

### Today tab addition

- `JourneySnippetCard.swift` (new, in `Features/Today/`) — one-line summary using `JourneyVelocity`/`WeightStats.toGoal`: `"Day \(daysSinceStart) · \(percentToGoal)% to goal · \(paceLabel)"`. `paceLabel` is "on pace" / "ahead of pace" / "behind pace" (only case that uses `Theme.warn`) / omitted entirely if no goal or velocity data yet.
- Inserted into `TodayView.body` directly under the date header, above `ritualCard`. Hidden entirely (not shown as an empty state) when there's no `goalKilograms` or zero `WeightEntry` rows — Today should never nag about a journey that hasn't started.
- Tapping the card navigates to the Progress tab (`router.selection = .progress`), consistent with the existing `ReportShortcutCard` pattern already in `Today/`.

### History tab addition

- `HistoryView.monthGrid` / `dayCell`: add a third indicator dot (reusing the existing two-dot legend pattern — pill taken / side effect) for "weigh-in logged," plus a distinct marker (e.g. a small ring) on days a `JourneyMilestone` was first reached. Legend row gains one entry.
- `DayDetailSheet`: add a `Section("Weight")` between "Dose" and "Side effects" showing that day's `WeightEntry` (if any) via `UnitFormat.weightString`, with the same edit/delete affordance the Progress tab's weigh-in list already has.
- No changes to `CalendarLayout.swift` (leading-blank math is unaffected) or to the History navigation title/month paging.

## Empty / sparse-data states

- Zero entries: keep existing `baselineNudge` ("Add your starting weight...") — journey UI (ring/timeline/insights) simply doesn't render until there's a baseline.
- 1 entry: progress ring + header render (0 velocity, no projection); timeline shows only "Start"; insights card hidden; activity feed shows the single weigh-in.
- No `goalKilograms` set: progress ring shows total change instead of % (can't compute % without a goal); timeline milestones hidden (they're goal-relative); insights that depend on goal distance are skipped, general-pace insights still allowed.

## Visual language

- `Theme.heroGradient` (primary teal → mint) for the progress ring and header background
- `Theme.warn` (orange) reserved for genuinely behind-pace states only — never decorative
- `Theme.cardCornerRadius` (16pt) on every card, via existing `Card` component
- Reuse `SectionHeader`, `StatBadge`, `PillCTAButton` as-is; no new design-system components
- Motion: progress ring animates on appear/update (`.animation` on the ring's trim), activity feed rows insert with a subtle transition — no confetti in v1 (spec reserves that for "major milestones," out of scope here)

## Visual reference (MeAgain app screen recording)

A competitor GLP-1 app ("MeAgain") screen recording was reviewed as the visual gold standard. Concrete patterns adopted from it:

- **Progress ring style**: light gray track, single-color filled arc, large bold number centered, small caption below — used for `JourneyProgressCard`'s ring (matches what `WeightShortcutCard`/protein ring already do elsewhere in the app, so this is also internally consistent).
- **"My GLP-1 Journey" card layout**: caps-style title, a pill/badge in the top-right corner (their "0 days" badge → our streak or days-since-start badge), a compact stat column (Date / BMI / Weight / Weight Diff) — informs `JourneyHeaderView`'s stat layout.
- **Bottom horizontal date scrubber**: a draggable timeline strip with date labels — directly informs `JourneyTimelineView`'s interaction model (scrollable/draggable chips rather than a static row).
- **Medication-level decay chart**: solid line for actual data, dashed continuation for the projected/future portion — adopted for `chartCard`'s weight trend: extend the existing `Chart` with a dashed `LineMark` segment from the last real entry to the `JourneyVelocity.projectedCompletion` point.
- Card chrome (light gray fill, no border, generous internal padding, icon+label headers) — already matches GLPill's existing `Card` component, no change needed there.
- Confirms "Journey" is the standard vocabulary in this product category (their premium feature is literally called "Journey Card") — validates the naming used throughout this spec.

## Testing

- `Core/Logic/*` new types get Swift Testing unit tests (per repo convention — see `App/Tests`): milestone generation across start>goal and edge cases (0 entries, entries past goal, no goal set), velocity/projection math, insight generation (including the "must return `[]` rather than fabricate" cases), activity feed merge/sort ordering.
- View layer: manual verification in Simulator (existing repo has no SwiftUI snapshot tests today — not introducing that infrastructure here, consistent with "surgical changes").

## Rollout

- Branch `feat/build-tracker-v2` off `main`.
- Single PR touching: `Features/Progress/*` (redesign), `Features/Today/TodayView.swift` + new `JourneySnippetCard.swift`, `Features/History/HistoryView.swift` (calendar dots + day-detail Weight section), plus the new `Core/Logic/Journey*.swift` types shared by all three.
- Existing `ProgressScreen.swift` logic is redistributed, not deleted-and-rewritten from scratch.
- No CloudKit schema migration required (no new `@Model` types).
