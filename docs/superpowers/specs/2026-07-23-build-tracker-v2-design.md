# Build Tracker v2 — Journey-style Progress tab

**Status:** Approved for planning
**Branch:** `feat/build-tracker-v2`

## Problem

GLPill's current Progress tab (`ProgressScreen.swift`) shows isolated values: current weight, total change, a line chart, a list of weigh-ins, a share card. It answers "what is my weight" but not "how am I doing on my journey" — no sense of pace, no milestones, no narrative of progress over time.

## Goal

Redesign the Progress tab into a journey experience, in the spirit of Apple Health / Flighty / Linear: minimal, calm, every number has historical context, nothing displayed in isolation. Reuse GLPill's existing visual language (`Theme.swift`, `Components.swift`) and existing data — no new backend, no new external dependencies.

## Non-goals (explicitly deferred)

- Calendar view, GitHub-style activity heatmap
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

## Testing

- `Core/Logic/*` new types get Swift Testing unit tests (per repo convention — see `App/Tests`): milestone generation across start>goal and edge cases (0 entries, entries past goal, no goal set), velocity/projection math, insight generation (including the "must return `[]` rather than fabricate" cases), activity feed merge/sort ordering.
- View layer: manual verification in Simulator (existing repo has no SwiftUI snapshot tests today — not introducing that infrastructure here, consistent with "surgical changes").

## Rollout

- Branch `feat/build-tracker-v2` off `main`.
- Single PR replacing `ProgressScreen.swift` + new files above; existing `ProgressScreen.swift` logic is redistributed, not deleted-and-rewritten from scratch.
- No CloudKit schema migration required (no new `@Model` types).
