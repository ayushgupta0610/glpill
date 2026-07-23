# Build Tracker v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign GLPill's Progress tab into a journey experience (progress ring, timeline, auto-generated milestones, activity feed, insights), add a compact journey snippet to Today, and add weigh-in/milestone markers to History's calendar — all from existing data, no new SwiftData models.

**Architecture:** Four new pure-logic types in `Core/Logic/` (milestone generation, velocity/projection, insight generation, activity-feed merge) are unit tested in isolation. Five new SwiftUI views in `Features/Progress/` render those types and get wired into a restructured `ProgressScreen`. One new view in `Features/Today/` and small additive edits to `HistoryView.swift` reuse the same logic types.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Swift Charts, XCTest (this repo's existing test convention — not Swift Testing), XcodeGen.

**Spec:** `docs/superpowers/specs/2026-07-23-build-tracker-v2-design.md`

---

## Before you start

All commands run from the repo root: `/Users/gupta/Downloads/Development/Projects/glpill`

Build/test command (from `README.md`):
```bash
xcodegen generate
xcodebuild -project GLPill.xcodeproj -scheme GLPill \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

This repo uses **XcodeGen** with folder-referenced sources (`project.yml`) — any new `.swift` file dropped into `App/Sources/**` or `App/Tests/` is picked up automatically the next time `xcodegen generate` runs. You do not need to edit `project.yml` or the `.xcodeproj` by hand.

This repo's tests use **XCTest** (`import XCTest`, `XCTAssertEqual`), not Swift Testing — every existing file in `App/Tests/` follows this pattern (see `App/Tests/WeightStatsTests.swift`, `App/Tests/StreakCalculatorTests.swift`). Follow the same convention for consistency.

### Task 0: Create the feature branch

**Files:** none

- [ ] **Step 1: Create and switch to the branch**

```bash
git checkout -b feat/build-tracker-v2
```

Expected: `Switched to a new branch 'feat/build-tracker-v2'`

- [ ] **Step 2: Confirm clean starting state**

```bash
git status
```

Expected: `nothing to commit, working tree clean`

---

## Task 1: `JourneyMilestone` — milestone generation

**Files:**
- Create: `App/Sources/Core/Logic/JourneyMilestone.swift`
- Test: `App/Tests/JourneyMilestoneTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import GLPill

final class JourneyMilestoneTests: XCTestCase {
    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: Double(offset) * 86400)
    }

    func testGeneratesFiveMilestonesAt20PercentSteps() {
        let entries: [(date: Date, kg: Double)] = [
            (day(0), 100.0),
            (day(7), 95.0),
            (day(14), 90.0),
            (day(21), 85.0),
        ]
        let milestones = JourneyMilestones.generate(startKg: 100, goalKg: 80, entries: entries)

        XCTAssertEqual(milestones.count, 5)
        XCTAssertEqual(milestones.map(\.label), ["20%", "40%", "60%", "80%", "100%"])
        XCTAssertEqual(milestones.map(\.targetKg), [96, 92, 88, 84, 80], accuracy: 0.0001)
    }

    func testStampsReachedDateFromFirstQualifyingEntry() {
        let entries: [(date: Date, kg: Double)] = [
            (day(0), 100.0),
            (day(7), 95.0),
            (day(14), 90.0),
            (day(21), 85.0),
        ]
        let milestones = JourneyMilestones.generate(startKg: 100, goalKg: 80, entries: entries)

        XCTAssertEqual(milestones[0].reachedDate, day(7))  // 96kg crossed at 95kg
        XCTAssertEqual(milestones[1].reachedDate, day(14)) // 92kg crossed at 90kg
        XCTAssertEqual(milestones[2].reachedDate, day(21)) // 88kg crossed at 85kg
        XCTAssertNil(milestones[3].reachedDate)            // 84kg not yet reached
        XCTAssertNil(milestones[4].reachedDate)            // 80kg not yet reached
        XCTAssertTrue(milestones[0].isReached)
        XCTAssertFalse(milestones[3].isReached)
    }

    func testReturnsEmptyWithoutGoal() {
        let milestones = JourneyMilestones.generate(startKg: 100, goalKg: nil, entries: [])
        XCTAssertTrue(milestones.isEmpty)
    }

    func testReturnsEmptyWhenStartEqualsGoal() {
        let milestones = JourneyMilestones.generate(startKg: 80, goalKg: 80, entries: [])
        XCTAssertTrue(milestones.isEmpty)
    }

    func testUnsortedEntriesAreHandledCorrectly() {
        // Same data as above, shuffled — generate() must sort internally.
        let entries: [(date: Date, kg: Double)] = [
            (day(21), 85.0),
            (day(0), 100.0),
            (day(14), 90.0),
            (day(7), 95.0),
        ]
        let milestones = JourneyMilestones.generate(startKg: 100, goalKg: 80, entries: entries)
        XCTAssertEqual(milestones[0].reachedDate, day(7))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodegen generate && xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GLPillTests/JourneyMilestoneTests`
Expected: FAIL — `JourneyMilestones` / `JourneyMilestone` not found (file doesn't exist yet)

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

/// A single progress checkpoint between a journey's start and goal weight.
struct JourneyMilestone: Identifiable, Equatable {
    let id: Int
    let label: String
    let targetKg: Double
    let reachedDate: Date?

    var isReached: Bool { reachedDate != nil }
}

enum JourneyMilestones {
    private static let fractions: [Double] = [0.2, 0.4, 0.6, 0.8, 1.0]

    /// Five milestones at 20% increments of the start→goal distance, each
    /// stamped with the date weight first crossed that target (nil if not
    /// yet reached). Returns `[]` when there's no goal or start == goal —
    /// there's nothing to divide into steps.
    static func generate(
        startKg: Double,
        goalKg: Double?,
        entries: [(date: Date, kg: Double)]
    ) -> [JourneyMilestone] {
        guard let goalKg, startKg != goalKg else { return [] }
        let losing = goalKg < startKg
        let sortedEntries = entries.sorted { $0.date < $1.date }

        return fractions.enumerated().map { index, fraction in
            let targetKg = startKg + (goalKg - startKg) * fraction
            let reached = sortedEntries.first { losing ? $0.kg <= targetKg : $0.kg >= targetKg }
            return JourneyMilestone(
                id: index,
                label: "\(Int((fraction * 100).rounded()))%",
                targetKg: targetKg,
                reachedDate: reached?.date
            )
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GLPillTests/JourneyMilestoneTests`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Core/Logic/JourneyMilestone.swift App/Tests/JourneyMilestoneTests.swift
git commit -m "feat: add JourneyMilestone generation logic"
```

---

## Task 2: `JourneyVelocityCalculator` — velocity, projection, pace label

**Files:**
- Create: `App/Sources/Core/Logic/JourneyVelocity.swift`
- Test: `App/Tests/JourneyVelocityTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import GLPill

final class JourneyVelocityTests: XCTestCase {
    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: Double(offset) * 86400)
    }

    func testFewerThanTwoEntriesGivesZeroVelocityNoProjection() {
        let empty = JourneyVelocityCalculator.calculate(entries: [], goalKg: 80)
        XCTAssertEqual(empty.kgPerWeek, 0, accuracy: 0.0001)
        XCTAssertNil(empty.projectedCompletion)

        let single = JourneyVelocityCalculator.calculate(entries: [(day(0), 90.0)], goalKg: 80)
        XCTAssertEqual(single.kgPerWeek, 0, accuracy: 0.0001)
        XCTAssertNil(single.projectedCompletion)
    }

    func testTwoEntriesComputeRateButNoProjection() {
        // -0.2 kg/day over 7 days = -1.4 kg/week; needs >=3 entries to project.
        let entries: [(date: Date, kg: Double)] = [(day(0), 90.0), (day(7), 88.6)]
        let result = JourneyVelocityCalculator.calculate(entries: entries, goalKg: 80)
        XCTAssertEqual(result.kgPerWeek, -1.4, accuracy: 0.0001)
        XCTAssertNil(result.projectedCompletion)
    }

    func testThreeEntriesProjectCompletionDate() {
        // Constant -0.2 kg/day. Last entry 87.2kg at day 14, goal 80kg.
        // remaining = 7.2kg, days to close = 7.2 / 0.2 = 36 -> day 50.
        let entries: [(date: Date, kg: Double)] = [
            (day(0), 90.0), (day(7), 88.6), (day(14), 87.2),
        ]
        let result = JourneyVelocityCalculator.calculate(entries: entries, goalKg: 80)
        XCTAssertEqual(result.kgPerWeek, -1.4, accuracy: 0.0001)
        XCTAssertEqual(result.projectedCompletion, day(50))
    }

    func testNoProjectionWhenMovingAwayFromGoal() {
        // Gaining weight while goal is below start -> never projected.
        let entries: [(date: Date, kg: Double)] = [
            (day(0), 90.0), (day(7), 91.0), (day(14), 92.0),
        ]
        let result = JourneyVelocityCalculator.calculate(entries: entries, goalKg: 80)
        XCTAssertEqual(result.kgPerWeek, 1.0, accuracy: 0.0001)
        XCTAssertNil(result.projectedCompletion)
    }

    func testNoProjectionWithoutGoal() {
        let entries: [(date: Date, kg: Double)] = [
            (day(0), 90.0), (day(7), 88.6), (day(14), 87.2),
        ]
        let result = JourneyVelocityCalculator.calculate(entries: entries, goalKg: nil)
        XCTAssertNil(result.projectedCompletion)
    }

    func testPaceLabels() {
        XCTAssertEqual(JourneyVelocityCalculator.paceLabel(kgPerWeek: -0.5).text, "Losing steadily")
        XCTAssertFalse(JourneyVelocityCalculator.paceLabel(kgPerWeek: -0.5).isWarning)

        XCTAssertEqual(JourneyVelocityCalculator.paceLabel(kgPerWeek: 0.5).text, "Trending up")
        XCTAssertTrue(JourneyVelocityCalculator.paceLabel(kgPerWeek: 0.5).isWarning)

        XCTAssertEqual(JourneyVelocityCalculator.paceLabel(kgPerWeek: 0.01).text, "Holding steady")
        XCTAssertFalse(JourneyVelocityCalculator.paceLabel(kgPerWeek: 0.01).isWarning)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GLPillTests/JourneyVelocityTests`
Expected: FAIL — `JourneyVelocityCalculator` not found

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

struct JourneyVelocity: Equatable {
    let kgPerWeek: Double
    let projectedCompletion: Date?
}

enum JourneyVelocityCalculator {
    /// Average weekly rate of change over the last 4 entries (or fewer),
    /// plus — with >=3 entries and a goal, moving toward it — the projected
    /// date of reaching goalKg by extrapolating that rate. No projection
    /// with fewer entries, no goal, or a rate moving away from the goal.
    static func calculate(entries: [(date: Date, kg: Double)], goalKg: Double?) -> JourneyVelocity {
        let sorted = entries.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return JourneyVelocity(kgPerWeek: 0, projectedCompletion: nil) }

        let window = Array(sorted.suffix(4))
        let first = window.first!
        let last = window.last!
        let days = last.date.timeIntervalSince(first.date) / 86400
        guard days > 0 else { return JourneyVelocity(kgPerWeek: 0, projectedCompletion: nil) }
        let kgPerDay = (last.kg - first.kg) / days
        let kgPerWeek = kgPerDay * 7

        guard let goalKg, sorted.count >= 3, abs(kgPerDay) > 0.001 else {
            return JourneyVelocity(kgPerWeek: kgPerWeek, projectedCompletion: nil)
        }

        let remainingKg = last.kg - goalKg
        let movingTowardGoal = (remainingKg > 0 && kgPerDay < 0) || (remainingKg < 0 && kgPerDay > 0)
        guard movingTowardGoal else {
            return JourneyVelocity(kgPerWeek: kgPerWeek, projectedCompletion: nil)
        }

        let daysRemaining = remainingKg / -kgPerDay
        let projected = Calendar.current.date(byAdding: .day, value: Int(daysRemaining.rounded()), to: last.date)
        return JourneyVelocity(kgPerWeek: kgPerWeek, projectedCompletion: projected)
    }

    /// Direction-based pace label. There's no target date in `UserSettings`,
    /// so this describes trend direction rather than an invented "on/behind
    /// schedule" concept the data can't actually support.
    static func paceLabel(kgPerWeek: Double) -> (text: String, isWarning: Bool) {
        if kgPerWeek < -0.05 {
            return ("Losing steadily", false)
        } else if kgPerWeek > 0.05 {
            return ("Trending up", true)
        } else {
            return ("Holding steady", false)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GLPillTests/JourneyVelocityTests`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Core/Logic/JourneyVelocity.swift App/Tests/JourneyVelocityTests.swift
git commit -m "feat: add JourneyVelocityCalculator (rate, projection, pace label)"
```

---

## Task 3: `JourneyInsights` — computed insight sentences

**Files:**
- Create: `App/Sources/Core/Logic/JourneyInsight.swift`
- Test: `App/Tests/JourneyInsightTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import GLPill

final class JourneyInsightTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: utc, year: year, month: month, day: day).date!
    }

    func testGeneratesSlowerPaceInsight() {
        let now = date(2026, 3, 15)
        // This month (Feb 15 - Mar 15): -2kg over 18 days -> -0.7778 kg/week.
        // Last month (Jan 15 - Feb 15): -3kg over 21 days -> -1.0 kg/week.
        // |thisRate| < |lastRate| -> "slower", ~22% change.
        let entries: [(date: Date, kg: Double)] = [
            (date(2026, 1, 20), 94.0),
            (date(2026, 2, 10), 91.0),
            (date(2026, 2, 20), 90.0),
            (date(2026, 3, 10), 88.0),
        ]
        let insights = JourneyInsights.generate(entries: entries, now: now, calendar: utc)
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights[0].text, "You're losing weight 22% slower than last month.")
    }

    func testGeneratesFasterPaceInsight() {
        let now = date(2026, 3, 15)
        // This month (Feb 20 - Mar 10): -3kg over 18 days -> -1.1667 kg/week.
        // Last month (Jan 20 - Feb 10): -2kg over 21 days -> -0.6667 kg/week.
        // |thisRate| > |lastRate| -> "faster", 75% change.
        let entries: [(date: Date, kg: Double)] = [
            (date(2026, 1, 20), 94.0),
            (date(2026, 2, 10), 92.0),
            (date(2026, 2, 20), 91.0),
            (date(2026, 3, 10), 88.0),
        ]
        let insights = JourneyInsights.generate(entries: entries, now: now, calendar: utc)
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights[0].text, "You're losing weight 75% faster than last month.")
    }

    func testReturnsEmptyWithInsufficientDataInEitherWindow() {
        let now = date(2026, 3, 15)
        // Only one entry this month.
        let entries: [(date: Date, kg: Double)] = [
            (date(2026, 1, 20), 94.0),
            (date(2026, 2, 10), 91.0),
            (date(2026, 3, 10), 88.0),
        ]
        XCTAssertTrue(JourneyInsights.generate(entries: entries, now: now, calendar: utc).isEmpty)
    }

    func testReturnsEmptyWhenChangeIsBelowNoiseThreshold() {
        let now = date(2026, 3, 15)
        // Last month (Jan 20 - Feb 10): -3kg over 21 days -> exactly -1.0 kg/week.
        // This month (Feb 20 - Mar 10): -2.57kg over 18 days -> -0.9994 kg/week.
        // <5% change -> should not claim a trend.
        let entries: [(date: Date, kg: Double)] = [
            (date(2026, 1, 20), 94.0),
            (date(2026, 2, 10), 91.0),
            (date(2026, 2, 20), 90.0),
            (date(2026, 3, 10), 87.43),
        ]
        XCTAssertTrue(JourneyInsights.generate(entries: entries, now: now, calendar: utc).isEmpty)
    }

    func testReturnsEmptyWhenDirectionFlips() {
        let now = date(2026, 3, 15)
        // Losing last month, gaining this month -> ambiguous to phrase, skip.
        let entries: [(date: Date, kg: Double)] = [
            (date(2026, 1, 20), 90.0),
            (date(2026, 2, 10), 88.0),
            (date(2026, 2, 20), 89.0),
            (date(2026, 3, 10), 91.0),
        ]
        XCTAssertTrue(JourneyInsights.generate(entries: entries, now: now, calendar: utc).isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GLPillTests/JourneyInsightTests`
Expected: FAIL — `JourneyInsights` not found

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

struct JourneyInsight: Equatable {
    let text: String
}

enum JourneyInsights {
    /// Up to one template-filled sentence comparing this month's pace to
    /// last month's. Returns `[]` whenever there isn't enough data to
    /// support a claim, the trend direction is ambiguous, or the change is
    /// within noise (<5%) — never fabricates a pace it can't back up.
    static func generate(
        entries: [(date: Date, kg: Double)],
        now: Date,
        calendar: Calendar = .current
    ) -> [JourneyInsight] {
        guard let recentStart = calendar.date(byAdding: .month, value: -1, to: now),
              let priorStart = calendar.date(byAdding: .month, value: -2, to: now) else {
            return []
        }

        let recent = entries.filter { $0.date > recentStart && $0.date <= now }
        let prior = entries.filter { $0.date > priorStart && $0.date <= recentStart }
        guard recent.count >= 2, prior.count >= 2 else { return [] }

        guard let recentRate = weeklyRate(recent), let priorRate = weeklyRate(prior), priorRate != 0 else {
            return []
        }
        guard (recentRate < 0) == (priorRate < 0) else { return [] }

        let percentChange = abs((recentRate - priorRate) / priorRate) * 100
        guard percentChange >= 5 else { return [] }

        let direction = abs(recentRate) > abs(priorRate) ? "faster" : "slower"
        let text = "You're losing weight \(Int(percentChange.rounded()))% \(direction) than last month."
        return [JourneyInsight(text: text)]
    }

    private static func weeklyRate(_ entries: [(date: Date, kg: Double)]) -> Double? {
        let sorted = entries.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last, first.date != last.date else { return nil }
        let days = last.date.timeIntervalSince(first.date) / 86400
        return (last.kg - first.kg) / days * 7
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GLPillTests/JourneyInsightTests`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Core/Logic/JourneyInsight.swift App/Tests/JourneyInsightTests.swift
git commit -m "feat: add JourneyInsights pace-comparison generator"
```

---

## Task 4: `ActivityFeed` — merged activity events

**Files:**
- Create: `App/Sources/Core/Logic/ActivityEvent.swift`
- Test: `App/Tests/ActivityEventTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import GLPill

final class ActivityEventTests: XCTestCase {
    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: Double(offset) * 86400)
    }

    func testMergesAndSortsDescending() {
        let milestone = JourneyMilestone(id: 0, label: "20%", targetKg: 88, reachedDate: day(2))
        let events = ActivityFeed.merge(
            weightEntries: [(id: "w1", date: day(0), kg: 90.0)],
            doseLogs: [(id: "d1", date: day(1))],
            milestones: [milestone]
        )

        XCTAssertEqual(events.map(\.id), ["milestone-0", "dose-d1", "weight-w1"])
        XCTAssertEqual(events.map(\.date), [day(2), day(1), day(0)])
    }

    func testExcludesUnreachedMilestones() {
        let unreached = JourneyMilestone(id: 1, label: "40%", targetKg: 84, reachedDate: nil)
        let events = ActivityFeed.merge(weightEntries: [], doseLogs: [], milestones: [unreached])
        XCTAssertTrue(events.isEmpty)
    }

    func testEmptyInputsGiveEmptyFeed() {
        let events = ActivityFeed.merge(weightEntries: [], doseLogs: [], milestones: [])
        XCTAssertTrue(events.isEmpty)
    }

    func testEventKindsCarryTheirPayload() {
        let events = ActivityFeed.merge(
            weightEntries: [(id: "w1", date: day(0), kg: 90.5)],
            doseLogs: [],
            milestones: []
        )
        guard case .weighIn(let kg) = events[0].kind else {
            return XCTFail("expected .weighIn")
        }
        XCTAssertEqual(kg, 90.5, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GLPillTests/ActivityEventTests`
Expected: FAIL — `ActivityFeed` / `ActivityEvent` not found

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

struct ActivityEvent: Identifiable {
    enum Kind {
        case weighIn(kg: Double)
        case dose
        case milestone(JourneyMilestone)
    }

    let id: String
    let date: Date
    let kind: Kind
}

enum ActivityFeed {
    /// Merges weigh-ins, doses, and reached milestones into one
    /// reverse-chronological feed. Unreached milestones (`reachedDate ==
    /// nil`) are excluded — they haven't happened yet, so they're not an
    /// activity event.
    static func merge(
        weightEntries: [(id: String, date: Date, kg: Double)],
        doseLogs: [(id: String, date: Date)],
        milestones: [JourneyMilestone]
    ) -> [ActivityEvent] {
        var events: [ActivityEvent] = []
        events += weightEntries.map { ActivityEvent(id: "weight-\($0.id)", date: $0.date, kind: .weighIn(kg: $0.kg)) }
        events += doseLogs.map { ActivityEvent(id: "dose-\($0.id)", date: $0.date, kind: .dose) }
        events += milestones.compactMap { milestone in
            guard let reachedDate = milestone.reachedDate else { return nil }
            return ActivityEvent(id: "milestone-\(milestone.id)", date: reachedDate, kind: .milestone(milestone))
        }
        return events.sorted { $0.date > $1.date }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GLPillTests/ActivityEventTests`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Core/Logic/ActivityEvent.swift App/Tests/ActivityEventTests.swift
git commit -m "feat: add ActivityFeed merge/sort logic"
```

---

## Task 5: `JourneyHeaderView`

**Files:**
- Create: `App/Sources/Features/Progress/JourneyHeaderView.swift`

No new logic here — pure presentation of values the caller computes, so no unit test (per spec's Testing section: view layer is verified manually in Simulator, this repo has no SwiftUI snapshot test infrastructure and this plan isn't introducing it).

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

/// Title + "Day N · X% to goal · <pace>" summary line for the Progress tab.
struct JourneyHeaderView: View {
    let daysSinceStart: Int
    let percentToGoal: Int?
    let paceText: String
    let paceIsWarning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Weight Loss Journey")
                .font(.largeTitle.bold())
            HStack(spacing: 6) {
                Text("Day \(daysSinceStart)")
                if let percentToGoal {
                    Text("· \(percentToGoal)% to goal")
                }
                Text("· \(paceText)")
                    .foregroundStyle(paceIsWarning ? Theme.warn : Theme.primary)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add App/Sources/Features/Progress/JourneyHeaderView.swift
git commit -m "feat: add JourneyHeaderView"
```

---

## Task 6: `JourneyProgressCard`

**Files:**
- Create: `App/Sources/Features/Progress/JourneyProgressCard.swift`

- [ ] **Step 1: Write the view**

Ring style follows the MeAgain reference: light gray track, single filled arc in `Theme.heroGradient`, big number centered (see spec's Visual reference section).

```swift
import SwiftUI

struct JourneyProgressCard: View {
    /// 0...1, nil when no goal weight is set (ring track renders empty).
    let percentToGoal: Double?
    let currentWeightText: String
    let sinceLastWeekText: String
    let sinceStartText: String
    let velocityText: String
    let projectedCompletionText: String
    let streak: Int

    var body: some View {
        Card {
            SectionHeader(title: "Progress")
            HStack(spacing: 20) {
                ring
                VStack(alignment: .leading, spacing: 6) {
                    Text(sinceLastWeekText)
                        .font(.caption.weight(.medium))
                    Text(sinceStartText)
                        .font(.caption.weight(.medium))
                    Text(velocityText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(projectedCompletionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if streak > 0 {
                Divider()
                Label("\(streak)-day streak", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 12)
            if let percentToGoal {
                Circle()
                    .trim(from: 0, to: max(0, min(1, percentToGoal)))
                    .stroke(Theme.heroGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: percentToGoal)
            }
            VStack(spacing: 2) {
                Text(currentWeightText)
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let percentToGoal {
                    Text("\(Int((percentToGoal * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 110, height: 110)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add App/Sources/Features/Progress/JourneyProgressCard.swift
git commit -m "feat: add JourneyProgressCard with progress ring"
```

---

## Task 7: `JourneyTimelineView`

**Files:**
- Create: `App/Sources/Features/Progress/JourneyTimelineView.swift`

Interaction model follows the MeAgain reference's bottom date scrubber: a scrollable horizontal strip of chips (see spec's Visual reference section).

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct JourneyTimelineView: View {
    let startDate: Date
    let milestones: [JourneyMilestone]
    let projectedCompletion: Date?
    let metric: Bool

    @State private var selectedMilestone: JourneyMilestone?

    var body: some View {
        Card {
            SectionHeader(title: "Timeline")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    chip(title: "Start", date: startDate, isDone: true)
                    ForEach(milestones) { milestone in
                        Button {
                            selectedMilestone = milestone
                        } label: {
                            chip(title: milestone.label, date: milestone.reachedDate, isDone: milestone.isReached)
                        }
                        .buttonStyle(.plain)
                    }
                    if let projectedCompletion {
                        chip(title: "Goal", date: projectedCompletion, isDone: false, isProjected: true)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .sheet(item: $selectedMilestone) { milestone in
            milestoneDetail(milestone)
        }
    }

    private func chip(title: String, date: Date?, isDone: Bool, isProjected: Bool = false) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(isDone ? Theme.primary : Color(.systemGray5))
                .frame(width: 12, height: 12)
                .overlay {
                    if isProjected {
                        Circle().strokeBorder(Theme.primary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    }
                }
            Text(title)
                .font(.caption.weight(.semibold))
            Text(date.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "—")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 64)
    }

    @ViewBuilder
    private func milestoneDetail(_ milestone: JourneyMilestone) -> some View {
        VStack(spacing: 12) {
            Text(milestone.label)
                .font(.title2.bold())
            Text(UnitFormat.weightString(kilograms: milestone.targetKg, metric: metric))
                .font(.headline)
            if let reachedDate = milestone.reachedDate {
                Text("Reached \(reachedDate.formatted(date: .abbreviated, time: .omitted))")
                    .foregroundStyle(.secondary)
            } else {
                Text("Not reached yet")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .presentationDetents([.fraction(0.3)])
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add App/Sources/Features/Progress/JourneyTimelineView.swift
git commit -m "feat: add JourneyTimelineView"
```

---

## Task 8: `ActivityFeedView`

**Files:**
- Create: `App/Sources/Features/Progress/ActivityFeedView.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct ActivityFeedView: View {
    let events: [ActivityEvent]
    let metric: Bool

    var body: some View {
        Card {
            SectionHeader(title: "Activity")
            if events.isEmpty {
                Text("No activity yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let shown = Array(events.prefix(10))
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, event in
                        row(for: event)
                        if index != shown.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func row(for event: ActivityEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: event.kind))
                .foregroundStyle(Theme.primary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: event.kind))
                    .font(.subheadline.weight(.medium))
                Text(event.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func icon(for kind: ActivityEvent.Kind) -> String {
        switch kind {
        case .weighIn: "scalemass"
        case .dose: "pills.fill"
        case .milestone: "flag.fill"
        }
    }

    private func title(for kind: ActivityEvent.Kind) -> String {
        switch kind {
        case .weighIn(let kg):
            "Logged \(UnitFormat.weightString(kilograms: kg, metric: metric))"
        case .dose:
            "Dose logged"
        case .milestone(let milestone):
            "Milestone reached: \(milestone.label)"
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add App/Sources/Features/Progress/ActivityFeedView.swift
git commit -m "feat: add ActivityFeedView"
```

---

## Task 9: `JourneyInsightsCard`

**Files:**
- Create: `App/Sources/Features/Progress/JourneyInsightsCard.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

/// Renders nothing when there are no insights — no empty-state placeholder,
/// per spec (a card with nothing to say shouldn't take up space).
struct JourneyInsightsCard: View {
    let insights: [JourneyInsight]

    var body: some View {
        if !insights.isEmpty {
            Card {
                SectionHeader(title: "Insights")
                ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                    Label(insight.text, systemImage: "sparkles")
                        .font(.subheadline)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add App/Sources/Features/Progress/JourneyInsightsCard.swift
git commit -m "feat: add JourneyInsightsCard"
```

---

## Task 10: Wire `ProgressScreen` to the journey components

**Files:**
- Modify: `App/Sources/Features/Progress/ProgressScreen.swift`

This replaces `statsCard` usage with the new journey components and adds a dashed projection segment to the existing `chartCard`, per the spec's "dashed continuation" visual reference. Existing pieces (`chartCard`'s real-data plotting, `weighInsCard`, `shareCard`, `WeightEntrySheet` sheets, `baselineNudge`, `monthCard`, delete/edit logic) are preserved.

- [ ] **Step 1: Add computed properties for the new components**

Insert these private computed properties into `ProgressScreen`, right after the existing `sortedEntries` property (`App/Sources/Features/Progress/ProgressScreen.swift:68-70`):

```swift
    private var daysSinceStart: Int {
        guard let start = settingsList.first?.startDate else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0)
    }

    private var startKilograms: Double? {
        settingsList.first?.startKilograms ?? entries.first?.kilograms
    }

    private var percentToGoal: Double? {
        guard let startKg = startKilograms,
              let goalKg = settingsList.first?.goalKilograms,
              let currentKg = entries.last?.kilograms,
              startKg != goalKg else { return nil }
        return max(0, min(1, (startKg - currentKg) / (startKg - goalKg)))
    }

    private var journeyVelocity: JourneyVelocity {
        JourneyVelocityCalculator.calculate(
            entries: entries.map { (date: $0.date, kg: $0.kilograms) },
            goalKg: settingsList.first?.goalKilograms
        )
    }

    private var paceInfo: (text: String, isWarning: Bool) {
        JourneyVelocityCalculator.paceLabel(kgPerWeek: journeyVelocity.kgPerWeek)
    }

    private var sinceLastWeekText: String {
        guard let currentKg = entries.last?.kilograms,
              let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now),
              let priorEntry = sortedEntries.first(where: { $0.date <= weekAgo }) else {
            return "— since last week"
        }
        let delta = currentKg - priorEntry.kilograms
        let display = metric ? delta : delta / UnitFormat.kgPerLb
        return String(format: "%+.1f %@ since last week", display, metric ? "kg" : "lb")
    }

    private var sinceStartText: String {
        guard let change = WeightStats.totalChange(entries: entries.map { (date: $0.date, kg: $0.kilograms) }) else {
            return "— since start"
        }
        let display = metric ? change : change / UnitFormat.kgPerLb
        return String(format: "%+.1f %@ since start", display, metric ? "kg" : "lb")
    }

    private var velocityText: String {
        guard entries.count >= 2 else { return "Velocity —" }
        let display = metric ? journeyVelocity.kgPerWeek : journeyVelocity.kgPerWeek / UnitFormat.kgPerLb
        return String(format: "%.1f %@/week", abs(display), metric ? "kg" : "lb")
    }

    private var projectedCompletionText: String {
        guard let projected = journeyVelocity.projectedCompletion else { return "Est. completion —" }
        return "Est. goal \(projected.formatted(date: .abbreviated, time: .omitted))"
    }

    private var milestones: [JourneyMilestone] {
        guard let startKg = startKilograms, let goalKg = settingsList.first?.goalKilograms else { return [] }
        return JourneyMilestones.generate(
            startKg: startKg,
            goalKg: goalKg,
            entries: entries.map { (date: $0.date, kg: $0.kilograms) }
        )
    }

    private var activityEvents: [ActivityEvent] {
        ActivityFeed.merge(
            weightEntries: entries.map { (id: String(describing: $0.persistentModelID), date: $0.date, kg: $0.kilograms) },
            doseLogs: doseLogs.map { (id: String(describing: $0.persistentModelID), date: $0.date) },
            milestones: milestones
        )
    }

    private var insights: [JourneyInsight] {
        JourneyInsights.generate(entries: entries.map { (date: $0.date, kg: $0.kilograms) }, now: .now)
    }

    private var streak: Int {
        StreakCalculator.currentStreak(doseDays: doseLogs.map(\.date), today: .now, calendar: .current)
    }
```

- [ ] **Step 2: Restructure the body to include the journey components**

Replace the `VStack(spacing: 16)` contents in `body` (`App/Sources/Features/Progress/ProgressScreen.swift:20-32`):

```swift
                VStack(spacing: 16) {
                    monthCard
                    if entries.isEmpty {
                        baselineNudge
                    } else {
                        JourneyHeaderView(
                            daysSinceStart: daysSinceStart,
                            percentToGoal: percentToGoal.map { Int(($0 * 100).rounded()) },
                            paceText: paceInfo.text,
                            paceIsWarning: paceInfo.isWarning
                        )
                        JourneyProgressCard(
                            percentToGoal: percentToGoal,
                            currentWeightText: entries.last.map { UnitFormat.weightString(kilograms: $0.kilograms, metric: metric) } ?? "—",
                            sinceLastWeekText: sinceLastWeekText,
                            sinceStartText: sinceStartText,
                            velocityText: velocityText,
                            projectedCompletionText: projectedCompletionText,
                            streak: streak
                        )
                        if !milestones.isEmpty {
                            JourneyTimelineView(
                                startDate: settingsList.first?.startDate ?? entries.first?.date ?? .now,
                                milestones: milestones,
                                projectedCompletion: journeyVelocity.projectedCompletion,
                                metric: metric
                            )
                        }
                    }
                    chartCard
                    if !entries.isEmpty {
                        ActivityFeedView(events: activityEvents, metric: metric)
                        JourneyInsightsCard(insights: insights)
                        weighInsCard
                    }
                    shareCard
                }
                .padding()
```

- [ ] **Step 3: Add the dashed projection segment to `chartCard`**

In `chartCard` (`App/Sources/Features/Progress/ProgressScreen.swift:190-229`), inside the `else` branch's `Chart(entries) { ... }`, after the existing `AreaMark` block and before the closing brace of the `Chart` content, add:

```swift
                    if let last = entries.last,
                       let projected = journeyVelocity.projectedCompletion,
                       let goalKg = settingsList.first?.goalKilograms {
                        ForEach([(last.date, displayValue(last.kilograms)), (projected, displayValue(goalKg))], id: \.0) { point in
                            LineMark(x: .value("Date", point.0), y: .value("Weight", point.1))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                                .foregroundStyle(Theme.primary.opacity(0.5))
                        }
                    }
```

- [ ] **Step 4: Verify it compiles and existing tests still pass**

```bash
xcodegen generate
xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```
Expected: `** TEST SUCCEEDED **`, all existing + new logic tests pass.

- [ ] **Step 5: Manual verification in Simulator**

Open `GLPill.xcodeproj` in Xcode, run on an iPhone 17 Pro simulator, navigate to the Progress tab. Verify:
- With zero weigh-ins: `baselineNudge` still shows (no journey UI).
- After adding 2+ weigh-ins and a goal weight (Settings): header, ring, timeline, chart with dashed projection, activity feed, weigh-ins list, and share card all render without layout issues.
- Add a 3rd weigh-in a month apart to trigger an insight sentence; confirm it appears and reads sensibly.

- [ ] **Step 6: Commit**

```bash
git add App/Sources/Features/Progress/ProgressScreen.swift
git commit -m "feat: wire ProgressScreen to journey components and dashed projection"
```

---

## Task 11: Today tab journey snippet

**Files:**
- Create: `App/Sources/Features/Today/JourneySnippetCard.swift`
- Modify: `App/Sources/Features/Today/TodayView.swift`

- [ ] **Step 1: Write `JourneySnippetCard`**

```swift
import SwiftUI

struct JourneySnippetCard: View {
    @Environment(AppRouter.self) private var router
    let daysSinceStart: Int
    let percentToGoal: Int
    let paceText: String
    let paceIsWarning: Bool

    var body: some View {
        Button {
            router.selection = .progress
        } label: {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day \(daysSinceStart) · \(percentToGoal)% to goal")
                            .font(.subheadline.weight(.semibold))
                        Text(paceText)
                            .font(.caption)
                            .foregroundStyle(paceIsWarning ? Theme.warn : .secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Add a snippet-data helper and insert the card in `TodayView`**

`TodayView` already `@Query`s `WeightEntry` (sorted reverse, most recent first) and `UserSettings` — see `App/Sources/Features/Today/TodayView.swift:10-14`. Add this private struct + computed property near the existing `streak` property (`App/Sources/Features/Today/TodayView.swift:39-41`):

```swift
    private struct JourneySnippetData {
        let daysSinceStart: Int
        let percentToGoal: Int
        let paceText: String
        let paceIsWarning: Bool
    }

    /// Hidden (not an empty state) until there's a goal and at least one
    /// weigh-in — Today shouldn't nag about a journey that hasn't started.
    private var journeySnippet: JourneySnippetData? {
        guard let settings = settingsList.first,
              let goalKg = settings.goalKilograms,
              let currentKg = weightEntries.first?.kilograms else { return nil }
        let startKg = settings.startKilograms ?? currentKg
        guard startKg != goalKg else { return nil }

        let daysSinceStart = max(0, calendar.dateComponents([.day], from: settings.startDate, to: .now).day ?? 0)
        let percent = max(0, min(1, (startKg - currentKg) / (startKg - goalKg)))
        let velocity = JourneyVelocityCalculator.calculate(
            entries: weightEntries.map { (date: $0.date, kg: $0.kilograms) },
            goalKg: goalKg
        )
        let pace = JourneyVelocityCalculator.paceLabel(kgPerWeek: velocity.kgPerWeek)
        return JourneySnippetData(
            daysSinceStart: daysSinceStart,
            percentToGoal: Int((percent * 100).rounded()),
            paceText: pace.text,
            paceIsWarning: pace.isWarning
        )
    }
```

Then insert the card into `body`, right after the date `Text` and before `if showNotifDeniedBanner` (`App/Sources/Features/Today/TodayView.swift:50-51`):

```swift
                    if let snippet = journeySnippet {
                        JourneySnippetCard(
                            daysSinceStart: snippet.daysSinceStart,
                            percentToGoal: snippet.percentToGoal,
                            paceText: snippet.paceText,
                            paceIsWarning: snippet.paceIsWarning
                        )
                    }
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Manual verification in Simulator**

Run the app. With no goal/weigh-ins, Today shows no snippet. After setting a goal and logging a weigh-in, the snippet appears below the date and tapping it switches to the Progress tab.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Features/Today/JourneySnippetCard.swift App/Sources/Features/Today/TodayView.swift
git commit -m "feat: add journey snippet card to Today tab"
```

---

## Task 12: History calendar — weigh-in and milestone markers

**Files:**
- Modify: `App/Sources/Features/History/HistoryView.swift`

- [ ] **Step 1: Add weight data and computed marker sets**

Add a `WeightEntry` query alongside the existing queries in `HistoryView` (`App/Sources/Features/History/HistoryView.swift:13-15`):

```swift
    @Query(sort: \WeightEntry.date) private var weightEntries: [WeightEntry]
```

Add these computed properties near the existing `dosedDays`/`effectDays` (`App/Sources/Features/History/HistoryView.swift:21-27`):

```swift
    private var weighInDays: Set<Date> {
        Set(weightEntries.map { calendar.startOfDay(for: $0.date) })
    }

    private var milestoneDays: Set<Date> {
        guard let settings = settingsList.first, let goalKg = settings.goalKilograms else { return [] }
        let startKg = settings.startKilograms ?? weightEntries.first?.kilograms ?? goalKg
        let milestones = JourneyMilestones.generate(
            startKg: startKg,
            goalKg: goalKg,
            entries: weightEntries.map { (date: $0.date, kg: $0.kilograms) }
        )
        return Set(milestones.compactMap { $0.reachedDate.map { calendar.startOfDay(for: $0) } })
    }
```

- [ ] **Step 2: Add markers to `dayCell` and update its accessibility label**

Replace `dayCell` (`App/Sources/Features/History/HistoryView.swift:109-148`):

```swift
    private func dayCell(_ day: Date) -> some View {
        let dosed = dosedDays.contains(day)
        let hasEffect = effectDays.contains(day)
        let hasWeighIn = weighInDays.contains(day)
        let hasMilestone = milestoneDays.contains(day)
        let isFuture = day > calendar.startOfDay(for: .now)
        let isMissed = !dosed && !isFuture && planStart.map { day >= $0 } == true

        return Button {
            selectedDay = HistoryDay(date: day)
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(dosed ? .bold : .regular))
                    .foregroundStyle(dosed ? .white : (isFuture ? .secondary : .primary))
                    .frame(width: 32, height: 32)
                    .background(dosed ? Theme.primary : Color.clear, in: Circle())
                    .overlay {
                        if isMissed {
                            Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                        }
                        if hasMilestone {
                            Circle().stroke(Theme.mint, lineWidth: 2)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if dosed {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(1)
                        }
                    }
                HStack(spacing: 3) {
                    Circle().fill(hasEffect ? Theme.warn : Color.clear).frame(width: 5, height: 5)
                    Circle().fill(hasWeighIn ? Theme.primary : Color.clear).frame(width: 5, height: 5)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(accessibilityText(for: day, dosed: dosed, hasEffect: hasEffect, missed: isMissed, hasWeighIn: hasWeighIn, hasMilestone: hasMilestone))
    }
```

- [ ] **Step 3: Update `accessibilityText` and the legend**

Replace `accessibilityText` (`App/Sources/Features/History/HistoryView.swift:150-161`):

```swift
    private func accessibilityText(for day: Date, dosed: Bool, hasEffect: Bool, missed: Bool, hasWeighIn: Bool, hasMilestone: Bool) -> String {
        var parts = [day.formatted(date: .long, time: .omitted)]
        if dosed {
            parts.append("pill taken")
        } else if missed {
            parts.append("missed")
        } else {
            parts.append("no pill logged")
        }
        if hasEffect { parts.append("side effect logged") }
        if hasWeighIn { parts.append("weigh-in logged") }
        if hasMilestone { parts.append("milestone reached") }
        return parts.joined(separator: ", ")
    }
```

Add a third legend entry in `body` (`App/Sources/Features/History/HistoryView.swift:44-48`):

```swift
                        HStack(spacing: 16) {
                            legend(color: Theme.primary, text: "Pill taken")
                            legend(color: Theme.warn, text: "Side effect")
                            legend(color: Theme.mint, text: "Milestone")
                        }
```

- [ ] **Step 4: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Features/History/HistoryView.swift
git commit -m "feat: add weigh-in and milestone markers to History calendar"
```

---

## Task 13: History day detail — Weight section

**Files:**
- Modify: `App/Sources/Features/History/HistoryView.swift`

- [ ] **Step 1: Add a weight query and edit state to `DayDetailSheet`**

Add alongside `DayDetailSheet`'s existing `@Query` properties (`App/Sources/Features/History/HistoryView.swift:192-195`):

```swift
    @Query(sort: \WeightEntry.date) private var weightEntries: [WeightEntry]
```

Add alongside its existing `@State` properties (`App/Sources/Features/History/HistoryView.swift:196-197`):

```swift
    @State private var editingWeightEntry: WeightEntry?
```

- [ ] **Step 2: Insert the Weight section**

Insert a new `Section("Weight")` between the existing `Section("Dose")` and `Section("Side effects")` (`App/Sources/Features/History/HistoryView.swift:221-222`, right after the `Section("Dose")` block closes):

```swift
                Section("Weight") {
                    let dayEntries = weightEntries.filter { calendar.isDate($0.date, inSameDayAs: day) }
                    if dayEntries.isEmpty {
                        Text("No weigh-in logged")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(dayEntries) { entry in
                        Button {
                            editingWeightEntry = entry
                        } label: {
                            Text(UnitFormat.weightString(kilograms: entry.kilograms, metric: metric))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        deleteWeightEntries(dayEntries, at: offsets)
                    }
                }
```

- [ ] **Step 3: Add the edit sheet and delete function**

Add a `.sheet(item:)` modifier alongside the existing `.sheet(item: $editingEffect, ...)` modifier (`App/Sources/Features/History/HistoryView.swift:260-265`):

```swift
            .sheet(item: $editingWeightEntry, onDismiss: { editingWeightEntry = nil }) { entry in
                WeightEntrySheet(metric: metric, entry: entry)
                    .presentationDetents([.medium])
            }
```

Add `deleteWeightEntries` alongside the existing `deleteDoses`/`deleteEffects` functions (`App/Sources/Features/History/HistoryView.swift:285-303`):

```swift
    private func deleteWeightEntries(_ entries: [WeightEntry], at offsets: IndexSet) {
        for index in offsets {
            context.delete(entries[index])
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            errorMessage = "Your change couldn't be saved. Please try again."
        }
    }
```

- [ ] **Step 4: Verify it compiles and tests pass**

```bash
xcodegen generate
xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Manual verification in Simulator**

Log a weigh-in for today, open History, tap today's cell — confirm the Weight section shows it, tapping it opens the edit sheet, and swipe-to-delete removes it.

- [ ] **Step 6: Commit**

```bash
git add App/Sources/Features/History/HistoryView.swift
git commit -m "feat: add Weight section to History day detail sheet"
```

---

## Task 14: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

```bash
xcodegen generate
xcodebuild -project GLPill.xcodeproj -scheme GLPill -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```
Expected: `** TEST SUCCEEDED **` — 49 pre-existing tests + 20 new logic tests (5 milestone + 6 velocity + 5 insight + 4 activity feed) + 2 existing UI tests, all green.

- [ ] **Step 2: Full manual walkthrough in Simulator**

Fresh install (`-resetData` launch arg per README), complete onboarding with a goal weight, then:
- Log 3+ weigh-ins spanning at least 2 months, spaced so a milestone is crossed and an insight is generated.
- Today: confirm the journey snippet appears and routes to Progress on tap.
- Progress: confirm header, ring, timeline (tap a milestone chip), chart with dashed projection, activity feed, insights, weigh-ins list, and share card all render correctly in both kg and lb (toggle in Settings).
- History: confirm weigh-in dots and milestone rings appear on the correct days, and the day-detail Weight section works (view/edit/delete).
- Empty-data sweep: fresh account with no goal set, and an account with a goal but zero weigh-ins — confirm no crashes, no broken layouts, and the documented empty/sparse states from the spec hold (baseline nudge, hidden Today snippet, no timeline card, no insights card).

- [ ] **Step 3: Final commit if any fixes were needed during manual verification**

```bash
git add -A
git commit -m "fix: address issues found in manual verification"
```
(Skip this step if no fixes were needed.)

---

## Self-review notes

- **Spec coverage:** Problem/Goal → Tasks 1-13. Data sources → used as-is, no schema changes (verified no `@Model` additions anywhere in this plan). New code section → Tasks 1-9 match 1:1 with the spec's listed types and views. Today addition → Task 11. History addition → Tasks 12-13. Empty/sparse-data states → handled via optionals/guards throughout (Tasks 10-11) and explicitly re-verified in Task 14 Step 2. Visual language → `Theme.heroGradient`/`Theme.warn`/`Theme.cardCornerRadius` (via `Card`) used throughout Tasks 5-9. Visual reference (MeAgain) → ring style (Task 6), timeline scrubber (Task 7), dashed projection (Task 10 Step 3) all cite the spec's Visual reference section. Testing → Tasks 1-4 unit test all new logic; Tasks 5-13 note manual verification per spec's stated approach. Rollout → Task 0 (branch) through Task 14 (full verification).
- **Placeholder scan:** no TBD/TODO; every code step has complete, runnable code; every test has concrete expected values (hand-computed in the plan text next to each test).
- **Type consistency:** `JourneyMilestone`/`JourneyMilestones`, `JourneyVelocity`/`JourneyVelocityCalculator`, `JourneyInsight`/`JourneyInsights`, `ActivityEvent`/`ActivityFeed` names are used consistently from their defining task through every consuming task (10, 11, 12). `persistentModelID` string-wrapping for `ActivityEvent.id` is applied consistently in Task 10 (Progress) — Today and History don't need it since they don't render `ActivityFeed`.
