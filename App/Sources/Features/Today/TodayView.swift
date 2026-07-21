import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DoseLog.date) private var doseLogs: [DoseLog]
    @Query private var medications: [Medication]
    @Query(sort: \TitrationStep.order) private var titrationSteps: [TitrationStep]
    @Query private var settingsList: [UserSettings]
    @AppStorage("eatTimerEnd") private var eatTimerEnd: Double = 0
    @State private var showSideEffectSheet = false
    @State private var errorMessage: String?
    @State private var doseJustLogged = false
    @State private var celebratingMilestone: Int?

    private var store: TodayStore { TodayStore(context: context) }
    private var calendar: Calendar { .current }

    private var todayLog: DoseLog? {
        doseLogs.first { calendar.isDateInToday($0.date) }
    }

    private var streak: Int {
        StreakCalculator.currentStreak(doseDays: doseLogs.map(\.date), today: .now, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ritualCard
                    streakCard
                    IntakeCountersView(
                        onProtein: { grams in withErrorHandling { try store.addProtein(grams) } },
                        onWater: { ml in withErrorHandling { try store.addWater(ml) } }
                    )
                    sideEffectCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .sensoryFeedback(.success, trigger: doseJustLogged)
            .sheet(isPresented: $showSideEffectSheet) {
                SideEffectSheet { kind, severity, note in
                    withErrorHandling { try store.logSideEffect(kind, severity: severity, note: note) }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: .init(
                get: { celebratingMilestone != nil },
                set: { if !$0 { celebratingMilestone = nil } }
            )) {
                if let milestone = celebratingMilestone {
                    MilestoneCelebrationView(milestone: milestone)
                }
            }
            .alert("Couldn't save", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

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
                takePill: takePill,
                undo: todayLog != nil ? undoDose : nil
            )
        }
    }

    private var doseSubtitle: String {
        let steps = titrationSteps.map { (doseMg: $0.doseMg, durationWeeks: $0.durationWeeks) }
        let planStart = settingsList.first?.startDate ?? .now
        guard let position = TitrationProgress.position(steps: steps, planStart: planStart, today: .now, calendar: calendar) else {
            return "No dose plan — add one in Settings"
        }
        let dose = steps[position.stepIndex].doseMg
        var text = String(format: "%g mg — step %d of %d", dose, position.stepIndex + 1, steps.count)
        if let next = position.nextStepDate {
            text += " · next step \(next.formatted(date: .abbreviated, time: .omitted))"
        }
        return text
    }

    private var streakCard: some View {
        Card {
            HStack(spacing: 16) {
                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundStyle(streak > 0 ? .orange : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    if streak > 0 {
                        Text("\(streak)-day streak")
                            .font(.title3.bold())
                            .contentTransition(.numericText())
                        let longest = StreakCalculator.longestStreak(doseDays: doseLogs.map(\.date), calendar: calendar)
                        Text("Longest: \(longest) \(longest == 1 ? "day" : "days")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Start your streak")
                            .font(.title3.bold())
                        Text("Take today's pill to light the flame")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }

    private var sideEffectCard: some View {
        Card {
            SectionHeader(title: "Feeling off?")
            Text("Log side effects so your doctor report stays accurate.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                showSideEffectSheet = true
            } label: {
                Label("Log a side effect", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func takePill() {
        let wasAlreadyLogged = todayLog != nil
        withErrorHandling {
            let startTimer = try store.logDose()
            doseJustLogged.toggle()
            if startTimer {
                let minutes = settingsList.first?.waitWindowMinutes ?? 30
                eatTimerEnd = Date().addingTimeInterval(Double(minutes) * 60).timeIntervalSince1970
                ReminderScheduler.scheduleEatTimer(
                    using: UNNotificationScheduler(),
                    meds: settingsList.first?.morningMeds ?? []
                )
            }
        }
        if !wasAlreadyLogged { celebrateMilestoneIfReached() }
    }

    /// After a fresh dose log, fire the shareable Trophy Card once if the streak
    /// just crossed a milestone (7/30/100/365).
    private func celebrateMilestoneIfReached() {
        // Read the canonical dose list straight from the store logDose just wrote,
        // not the @Query (which can lag a run-loop tick).
        let days = ((try? context.fetch(FetchDescriptor<DoseLog>())) ?? []).map(\.date)
        let newStreak = StreakCalculator.currentStreak(doseDays: days, today: .now, calendar: calendar)
        guard let settings = settingsList.first,
              let milestone = StreakMilestone.newlyReached(streak: newStreak, lastCelebrated: settings.lastCelebratedMilestone)
        else { return }
        settings.lastCelebratedMilestone = milestone
        try? context.save()
        celebratingMilestone = milestone
    }

    /// Undoes today's dose log — only meaningful same-day. Clears the eat timer,
    /// cancels its pending notification, and returns the card to `.notTaken`.
    private func undoDose() {
        guard let todayLog else { return }
        withErrorHandling {
            try store.deleteDose(todayLog)
            eatTimerEnd = 0
            UNNotificationScheduler().removePending(ids: [ReminderScheduler.eatTimerId])
        }
    }

    private func withErrorHandling(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            errorMessage = "Your change couldn't be saved. Please try again."
        }
    }
}
