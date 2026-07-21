# Phase 5 — Onboarding rebuild (detailed implementation spec)

Companion to the main plan. Implement EXACTLY this. The new 11-step flow (0-indexed):
`0 Welcome · 1 Stage · 2 Medication · 3 DoseLadder · 4 DailyTime · 5 WaitWindow (conditional) · 6 MorningMeds · 7 Concerns · 8 Goals · 9 ReminderStyle · 10 PlanReveal`.

**Dropped from onboarding:** the old Weight step (weight is optional, logged in-app) and the old manual TitrationSetup + Reminder steps. **Not included (deferred):** Apple Health step. **Kept:** Welcome (new copy), Medication (existing + Wegovy subtitle), MorningMeds (existing, unchanged).

Reuse: `PillCTAButton(title:systemImage:action:)`, `Card`, `Theme`, `MedicationLadder.doses(for:)`. New step views go in `App/Sources/Features/Onboarding/Steps/` as non-private structs.

---

## Task 14 — OnboardingStore fields + `complete(in:)`

Add to `OnboardingStore` (after `reminderMinute`):
```swift
    var stage: String?
    var waitWindowMinutes = 30
    var concerns: [String] = []
    var goals: [String] = []
    var reminderStyle = "full"
    /// Convenience for the conditional wait-window step.
    var requiresEmptyStomach: Bool { kind.defaultRequiresEmptyStomach }
```

In `complete(in:)`, change the `UserSettings(...)` insert to pass the new fields:
```swift
        context.insert(UserSettings(
            onboardingComplete: true,
            usesMetric: usesMetric,
            goalKilograms: goalKg,
            startKilograms: startKg,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            startDate: now,
            morningMeds: MorningMeds.normalize(morningMeds),
            waitWindowMinutes: waitWindowMinutes,
            onboardingStage: stage,
            sideEffectConcerns: concerns,
            goals: goals,
            reminderStyle: reminderStyle
        ))
```

**Test** — the existing `App/Tests/OnboardingStoreTests.swift` is an **XCTestCase** (NOT Swift Testing). ADD this method to the existing class (do not create a new file, do not import Testing):
```swift
    @MainActor
    func testCompletePersistsNewOnboardingAnswers() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = OnboardingStore()
        store.kind = .wegovyPill
        store.stage = "switchingFromInjections"
        store.waitWindowMinutes = 45
        store.concerns = ["nausea"]
        store.goals = ["consistency"]
        store.reminderStyle = "pillOnly"
        store.steps = [OnboardingStore.DraftStep(doseMg: 1.5, durationWeeks: 4)]
        try store.complete(in: context)
        let s = try XCTUnwrap(try context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertEqual(s.waitWindowMinutes, 45)
        XCTAssertEqual(s.onboardingStage, "switchingFromInjections")
        XCTAssertEqual(s.sideEffectConcerns, ["nausea"])
        XCTAssertEqual(s.goals, ["consistency"])
        XCTAssertEqual(s.reminderStyle, "pillOnly")
    }
```
Run `... test -only-testing:GLPillTests/OnboardingStoreTests` → green. Commit: `feat: onboarding store carries new answers`

---

## Task 15 — New step views (one file each in `Features/Onboarding/Steps/`)

All follow the same shell: title, subtitle, options, `PillCTAButton` CTA, `Color(.systemGroupedBackground)` background, `.padding(.horizontal)`. Selected option = filled circle + `Theme.primary` stroke.

### `Steps/OnboardingOption.swift` — shared row + multiselect helpers
```swift
import SwiftUI

/// A tappable selection row used across onboarding steps.
struct OnboardingOptionRow: View {
    let title: String
    let subtitle: String?
    let selected: Bool
    let multi: Bool
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                Image(systemName: iconName)
                    .foregroundStyle(selected ? Theme.primary : Color.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .stroke(selected ? Theme.primary : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
    private var iconName: String {
        if multi { return selected ? "checkmark.square.fill" : "square" }
        return selected ? "checkmark.circle.fill" : "circle"
    }
}
```

### `Steps/StageStep.swift`
```swift
import SwiftUI

struct StageStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    private let options: [(id: String, label: String)] = [
        ("aboutToStart", "I'm about to start"),
        ("firstWeeks", "I'm in my first few weeks"),
        ("aWhile", "I've been on it a while"),
        ("switchingFromInjections", "I'm switching from injections"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Where are you in your pill journey?").font(.title.bold()).padding(.top, 24)
            Text("So we set the right expectations from day one.").font(.subheadline).foregroundStyle(.secondary)
            ForEach(options, id: \.id) { opt in
                OnboardingOptionRow(title: opt.label, subtitle: nil, selected: store.stage == opt.id, multi: false) {
                    store.stage = opt.id
                }
            }
            Spacer()
            PillCTAButton(title: "Continue", systemImage: "arrow.right") { next() }.padding(.bottom, 24)
        }
        .padding(.horizontal).background(Color(.systemGroupedBackground))
    }
}
```

### `Steps/DoseLadderStep.swift`
Replaces manual titration entry. Picks one dose from the drug's ladder (or "Not sure"), writing a single `DraftStep` into `store.steps`. Custom kind (empty ladder) → a manual mg field.
```swift
import SwiftUI

struct DoseLadderStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    @State private var customMg: Double? = nil

    private var ladder: [Double] { MedicationLadder.doses(for: store.kind) }
    private var selectedMg: Double? { store.steps.first?.doseMg }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your current dose?").font(.title.bold()).padding(.top, 24)
            Text("Most people begin at the lowest dose and step up about every 30 days. Not sure is fine.")
                .font(.subheadline).foregroundStyle(.secondary)
            if ladder.isEmpty {
                LabeledContent("Dose (mg)") {
                    TextField("0", value: $customMg, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                        .onChange(of: customMg) { _, v in if let v { store.steps = [.init(doseMg: v, durationWeeks: 4)] } }
                }
                .padding().background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(ladder, id: \.self) { dose in
                            OnboardingOptionRow(title: "\(dose.formatted()) mg", subtitle: nil, selected: selectedMg == dose, multi: false) {
                                store.steps = [.init(doseMg: dose, durationWeeks: 4)]
                            }
                        }
                        OnboardingOptionRow(title: "Not sure", subtitle: "You can change this anytime", selected: false, multi: false) {
                            store.steps = [.init(doseMg: ladder.first ?? 0.8, durationWeeks: 4)]; next()
                        }
                    }
                }
            }
            Spacer()
            PillCTAButton(title: "Continue", systemImage: "arrow.right") { next() }.padding(.bottom, 24)
        }
        .padding(.horizontal).background(Color(.systemGroupedBackground))
    }
}
```

### `Steps/DailyTimeStep.swift`
Sets the daily pill time (stored as `reminderHour`/`reminderMinute`).
```swift
import SwiftUI

struct DailyTimeStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    @State private var time = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? .now

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When will you take it each day?").font(.title.bold()).padding(.top, 24)
            Text(store.requiresEmptyStomach
                 ? "Oral semaglutide works best first thing, on an empty stomach."
                 : "Pick a time you'll remember — Foundayo works any time of day.")
                .font(.subheadline).foregroundStyle(.secondary)
            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
            Spacer()
            PillCTAButton(title: "Continue", systemImage: "arrow.right") {
                let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                store.reminderHour = c.hour ?? 7
                store.reminderMinute = c.minute ?? 0
                next()
            }.padding(.bottom, 24)
        }
        .padding(.horizontal).background(Color(.systemGroupedBackground))
    }
}
```

### `Steps/WaitWindowStep.swift`
```swift
import SwiftUI

struct WaitWindowStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    private let options: [(min: Int, label: String, note: String)] = [
        (30, "30 minutes", "the minimum"), (45, "45 minutes", ""),
        (60, "1 hour", ""), (120, "As long as I can", "up to 2h"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How long can you wait before breakfast?").font(.title.bold()).padding(.top, 24)
            Text("You must wait at least 30 minutes. Waiting longer absorbs more of the medicine — we'll time it for you.")
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(options, id: \.min) { opt in
                OnboardingOptionRow(title: opt.label, subtitle: opt.note.isEmpty ? nil : opt.note,
                                    selected: store.waitWindowMinutes == opt.min, multi: false) {
                    store.waitWindowMinutes = opt.min
                }
            }
            Spacer()
            PillCTAButton(title: "Continue", systemImage: "arrow.right") { next() }.padding(.bottom, 24)
        }
        .padding(.horizontal).background(Color(.systemGroupedBackground))
    }
}
```

### `Steps/ConcernsStep.swift`
```swift
import SwiftUI

struct ConcernsStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    private let options: [(id: String, label: String)] = [
        ("nausea", "Nausea"), ("constipation", "Constipation"),
        ("lowAppetite", "Low appetite / food noise"), ("fatigue", "Fatigue"),
        ("reflux", "Reflux / burping"), ("none", "Nothing yet"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What are you most worried about?").font(.title.bold()).padding(.top, 24)
            Text("We'll tailor gentle tips and make these one-tap to log.").font(.subheadline).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(options, id: \.id) { opt in
                        OnboardingOptionRow(title: opt.label, subtitle: nil, selected: store.concerns.contains(opt.id), multi: true) {
                            toggle(opt.id)
                        }
                    }
                }
            }
            PillCTAButton(title: "Continue", systemImage: "arrow.right") { next() }.padding(.bottom, 24)
        }
        .padding(.horizontal).background(Color(.systemGroupedBackground))
    }
    private func toggle(_ id: String) {
        if store.concerns.contains(id) { store.concerns.removeAll { $0 == id } } else { store.concerns.append(id) }
    }
}
```

### `Steps/GoalsStep.swift`
Same shape as ConcernsStep, binding `store.goals`. Title "What should this app help with?", subtitle "We'll put what matters to you up front." Options:
`("pillDaily","Take my pill correctly every day")`, `("consistency","Build a streak & stay consistent")`, `("sideEffects","Manage side effects")`, `("doctor","Keep records for my doctor")`, `("weight","See my weight trend")`. Use the same multi-select `toggle` on `store.goals`.

### `Steps/ReminderStyleStep.swift`
Single-select on `store.reminderStyle`. Title "Never mistime a dose". Options:
`("full","Pill time + when my window clears")`, `("pillOnly","Just the pill reminder")`, `("none","No reminders")`. CTA "Continue" → next.

### `Steps/PlanRevealStep.swift`
```swift
import SwiftUI

struct PlanRevealStep: View {
    @Bindable var store: OnboardingStore
    let finish: () -> Void
    private var pillName: String { store.kind == .custom ? (store.customName.isEmpty ? "your pill" : store.customName) : store.kind.defaultDisplayName }
    private var timeText: String {
        let c = DateComponents(hour: store.reminderHour, minute: store.reminderMinute)
        let d = Calendar.current.date(from: c) ?? .now
        return d.formatted(date: .omitted, time: .shortened)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Text("YOUR DAILY PLAN").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.85))
                Text("You're set 🌱").font(.largeTitle.bold()).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(timeText) — take \(pillName)", systemImage: "pills.fill")
                    if store.requiresEmptyStomach {
                        Label("Wait \(store.waitWindowMinutes) min — we'll time it", systemImage: "clock.fill")
                    }
                    if let firstMed = store.morningMeds.first {
                        Label("Then — \(firstMed) + breakfast", systemImage: "fork.knife")
                    }
                    Label("Reminders on · streak starts today", systemImage: "flame.fill")
                }
                .font(.subheadline).foregroundStyle(.white)
                .padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding().frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 24))
            Text("Free to use. No card needed.").font(.caption).foregroundStyle(.secondary)
            Spacer()
            PillCTAButton(title: "Start day 1", systemImage: "checkmark") { finish() }.padding(.bottom, 24)
        }
        .padding(.horizontal).background(Color(.systemGroupedBackground))
    }
}
```

### Modify existing `WelcomeStep` (in `OnboardingFlow.swift`)
Change the title to `"The calm daily co-pilot for the GLP-1 pill"` and the body paragraph to: `"Take it right, remember your other morning meds, and watch steady progress — without the weight-loss noise."` Keep the bullet list and the "not medical advice" disclaimer.

### Modify existing `MedicationStep` (in `OnboardingFlow.swift`)
It already lists `MedicationKind.allCases` (now includes `wegovyPill`). Add a subtitle branch so `.wegovyPill` shows `"Empty stomach + 30-min wait — we'll time it for you"` (same as `.rybelsus`).

Commit after the views compile: `feat: new onboarding step views`

---

## Task 16 — Wire the 11-step flow (`OnboardingFlow.swift`)

- Set `private let totalSteps = 11`.
- Replace the `switch step` body with:
```swift
            switch step {
            case 0: WelcomeStep(next: advance)
            case 1: StageStep(store: store, next: advance)
            case 2: MedicationStep(store: store, next: advance)
            case 3: DoseLadderStep(store: store, next: advance)
            case 4: DailyTimeStep(store: store, next: advance)
            case 5: WaitWindowStep(store: store, next: advance)
            case 6: MorningMedsStep(store: store, next: advance)
            case 7: ConcernsStep(store: store, next: advance)
            case 8: GoalsStep(store: store, next: advance)
            case 9: ReminderStyleStep(store: store, next: advance)
            default: PlanRevealStep(store: store, finish: complete)
            }
```
- **Conditional wait-window skip:** change `advance()` so that when leaving DailyTime (step 4) into step 5 and the drug has no empty-stomach window, it skips WaitWindow:
```swift
    private func advance() {
        if step == 4 && !store.requiresEmptyStomach { step += 2 } else { step += 1 }
    }
```
- **Reminder scheduling by style:** in `complete()`, only schedule when `store.reminderStyle != "none"`. Keep the existing `try store.complete(in: context)` + authorization pattern; wrap the `ReminderScheduler.scheduleDaily(...)` call in `if store.reminderStyle != "none"`.
- Remove the now-unused `TitrationSetupStep`, `WeightStep`, and `ReminderStep` structs from `OnboardingFlow.swift` (grep first to confirm nothing else references them).

- `xcodegen generate`, then run onboarding end-to-end in the simulator per drug is ideal; at minimum `xcodebuild ... build` → SUCCEEDED and the renamed UI test `testOnboardingLeadsToTodayTab` still passes (update its step-through if the number of Continue taps changed — it must complete all 11 steps). Commit: `feat: 11-step pill-first onboarding flow`

**Note:** the UI test walks the onboarding screens; with 11 steps and the conditional skip it will need its tap sequence updated. Match the actual accessibility labels/buttons; the final assertion (Today tab exists) stays.
