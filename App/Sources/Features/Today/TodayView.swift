import SwiftUI
import SwiftData
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DoseLog.date) private var doseLogs: [DoseLog]
    @Query(sort: \Medication.createdAt) private var medications: [Medication]
    @Query(sort: \TitrationStep.order) private var titrationSteps: [TitrationStep]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @Query(sort: \UserSettings.createdAt) private var settingsList: [UserSettings]
    @AppStorage("eatTimerEnd") private var eatTimerEnd: Double = 0
    private enum ActiveSheet: Int, Identifiable { case log, weight, sideEffect; var id: Int { rawValue } }
    @State private var activeSheet: ActiveSheet?
    @State private var errorMessage: String?
    @State private var doseJustLogged = false
    @State private var celebratingMilestone: Int?
    @State private var undo: UndoAction?
    @State private var notificationsDenied = false
    @State private var notifBannerDismissed = false

    private struct UndoAction: Equatable {
        let id = UUID()
        let label: String
        let reverse: () -> Void
        static func == (lhs: UndoAction, rhs: UndoAction) -> Bool { lhs.id == rhs.id }
    }

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
                    if showNotifDeniedBanner {
                        notifDeniedBanner
                    }
                    ritualCard
                    if !(settingsList.first?.coachingDismissed ?? false),
                       let coaching = StageCoaching.message(
                           stage: settingsList.first?.onboardingStage,
                           requiresEmptyStomach: medications.first?.requiresEmptyStomach ?? false
                       ) {
                        StageCoachingCard(message: coaching, onDismiss: dismissCoaching)
                    }
                    if medications.first?.requiresEmptyStomach == true || !(settingsList.first?.morningMeds ?? []).isEmpty {
                        MorningSequenceCard(steps: morningSequence)
                    }
                    ForEach(TodayLayout.sections(goals: settingsList.first?.goals ?? []), id: \.self) { section in
                        sectionView(section)
                    }
                    Color.clear.frame(height: 76)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .task { await refreshNotificationStatus() }
            .overlay(alignment: .bottomTrailing) {
                Button { activeSheet = .log } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Theme.primary, in: Circle())
                        .shadow(radius: 8, y: 4)
                }
                .padding()
                .accessibilityLabel("Log something")
            }
            .overlay(alignment: .bottom) {
                if let undo {
                    undoSnackbar(undo)
                }
            }
            .animation(.snappy, value: undo)
            .navigationTitle("Today")
            .sensoryFeedback(.success, trigger: doseJustLogged)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .log:
                    LogSheet(
                        onPill: { activeSheet = nil; takePill() },
                        onWeight: { swapSheet(to: .weight) },
                        onWater: { activeSheet = nil; quickAddWater() },
                        onProtein: { activeSheet = nil; quickAddProtein() },
                        onSideEffect: { swapSheet(to: .sideEffect) }
                    )
                case .weight:
                    WeightEntrySheet(metric: settingsList.first?.usesMetric ?? false)
                case .sideEffect:
                    SideEffectSheet { kind, severity, note in
                        withErrorHandling { try store.logSideEffect(kind, severity: severity, note: note) }
                    }
                    .presentationDetents([.medium])
                }
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

    @ViewBuilder
    private func sectionView(_ section: TodaySection) -> some View {
        switch section {
        case .weightShortcut:
            WeightShortcutCard(
                latestKilograms: weightEntries.first?.kilograms,
                metric: settingsList.first?.usesMetric ?? false
            )
        case .reportShortcut:
            ReportShortcutCard()
        case .sideEffects:
            sideEffectCard
        case .medLevel:
            MedLevelPreviewCard(points: medLevelPoints, projection: medLevelProjection)
        case .streak:
            streakCard
        case .intake:
            IntakeCountersView(
                onProtein: { grams in withErrorHandling { try store.addProtein(grams) } },
                onWater: { ml in withErrorHandling { try store.addWater(ml) } },
                onSetProtein: { grams in withErrorHandling { try store.setProtein(grams: grams) } },
                onSetWater: { ml in withErrorHandling { try store.setWater(ml: ml) } }
            )
        }
    }

    private var medLevelPoints: [MedicationLevel.Point] {
        let kind = medications.first?.kind ?? .custom
        let halfLife = MedicationLevel.halfLifeHours(for: kind)
        // Only feed doses from the last ~5 half-lives; older doses have decayed to
        // near-zero and would otherwise stretch the fixed 40 samples too thin for a
        // user whose first dose is very old, making the recent curve inaccurate.
        let lookbackStart = Date.now.addingTimeInterval(-5 * halfLife * 3600)
        let doses = doseLogs
            .filter { $0.doseMg > 0 && $0.takenAt >= lookbackStart }
            .map { (date: $0.takenAt, mg: $0.doseMg) }
        return MedicationLevel.curve(doses: doses, halfLifeHours: halfLife, samples: 40, now: .now)
    }

    private var medLevelProjection: [MedicationLevel.Point] {
        let kind = medications.first?.kind ?? .custom
        let dose = store.currentDoseMg()
        return MedicationLevel.projection(dailyDoseMg: dose, halfLifeHours: MedicationLevel.halfLifeHours(for: kind), days: 7, samples: 40, startingFrom: .now)
    }

    /// Eat-timer end as a Date, but only while the window belongs to today.
    /// A stale `eatTimerEnd` from a prior day (not cleared until relaunch) would
    /// otherwise render "After 8:14 AM" for a long-closed window.
    private var activeWindowEnd: Date? {
        guard eatTimerEnd > 0 else { return nil }
        let end = Date(timeIntervalSince1970: eatTimerEnd)
        return calendar.isDateInToday(end) ? end : nil
    }

    private var morningSequence: [MorningSequence.Step] {
        let clear = activeWindowEnd
        return MorningSequence.make(
            pillTaken: todayLog != nil,
            pillName: medications.first?.displayName ?? "Your GLP-1 pill",
            hadWindow: medications.first?.requiresEmptyStomach ?? false,
            clearTime: clear,
            meds: settingsList.first?.morningMeds ?? []
        )
    }

    private var ritualState: RitualState {
        RitualState.make(
            todayLogged: todayLog != nil,
            requiresEmptyStomach: medications.first?.requiresEmptyStomach ?? false,
            windowEnd: activeWindowEnd,
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
                waitWindowMinutes: settingsList.first?.waitWindowMinutes ?? 30,
                takePill: takePill,
                undo: todayLog != nil ? undoDose : nil
            )
        }
    }

    private var doseSubtitle: String {
        let steps = titrationSteps.map { (doseMg: $0.doseMg, durationWeeks: $0.durationWeeks) }
        let planStart = settingsList.first?.startDate ?? .now
        guard let position = TitrationProgress.position(steps: steps, planStart: planStart, today: .now, calendar: calendar) else {
            return "Dose not set — add in Settings"
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

    /// Quick-add one cup of water (237 ml / ~8 oz) from the log sheet, with an Undo bar.
    private func quickAddWater() {
        withErrorHandling { try store.addWater(237) }
        let label = (settingsList.first?.usesMetric ?? false) ? "Added 237 ml" : "Added 8 oz"
        undo = UndoAction(label: label, reverse: { withErrorHandling { try store.addWater(-237) } })
    }

    /// Quick-add 25 g protein from the log sheet, with an Undo bar.
    private func quickAddProtein() {
        withErrorHandling { try store.addProtein(25) }
        undo = UndoAction(label: "Added 25 g", reverse: { withErrorHandling { try store.addProtein(-25) } })
    }

    private func undoSnackbar(_ action: UndoAction) -> some View {
        HStack(spacing: 12) {
            Text(action.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            Spacer()
            Button("Undo") {
                action.reverse()
                undo = nil
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.darkGray), in: Capsule())
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task(id: action.id) {
            try? await Task.sleep(for: .seconds(4))
            if undo == action { undo = nil }
        }
    }

    private var sideEffectCard: some View {
        Card {
            SectionHeader(title: "Feeling off?")
            Text("Log side effects so your doctor report stays accurate.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                activeSheet = .sideEffect
            } label: {
                Label("Log a side effect", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    /// Swaps the presented sheet. Dismissing first and setting the next target on
    /// the following runloop keeps `.sheet(item:)` reliable — a direct non-nil→non-nil
    /// change can be missed by SwiftUI, leaving no sheet presented.
    private func swapSheet(to next: ActiveSheet) {
        activeSheet = nil
        DispatchQueue.main.async { activeSheet = next }
    }

    /// Show the "reminders are off" banner only when the user expects reminders,
    /// the system has denied notification permission, and they haven't dismissed it.
    private var showNotifDeniedBanner: Bool {
        notificationsDenied
            && (settingsList.first?.reminderStyle ?? "full") != "none"
            && !notifBannerDismissed
    }

    private var notifDeniedBanner: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(Theme.warn)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reminders are off. Turn on notifications in Settings to get your daily nudge.")
                        .font(.subheadline)
                    Button("Open Settings") { openSystemSettings() }
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                Button {
                    notifBannerDismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Dismiss")
            }
        }
    }

    private func refreshNotificationStatus() async {
        notificationsDenied = await UNNotificationScheduler().authorizationStatus() == .denied
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    private func takePill() {
        let wasAlreadyLogged = todayLog != nil
        withErrorHandling {
            let startTimer = try store.logDose()
            doseJustLogged.toggle()
            if startTimer {
                let minutes = settingsList.first?.waitWindowMinutes ?? 30
                eatTimerEnd = Date().addingTimeInterval(Double(minutes) * 60).timeIntervalSince1970
                if (settingsList.first?.reminderStyle ?? "full") == "full" {
                    ReminderScheduler.scheduleEatTimer(
                        using: UNNotificationScheduler(),
                        waitWindowMinutes: settingsList.first?.waitWindowMinutes ?? 30
                    )
                }
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
        let previous = settings.lastCelebratedMilestone
        settings.lastCelebratedMilestone = milestone
        do {
            try context.save()
            // Present on the NEXT runloop so a same-tick `activeSheet = nil`
            // (Log-sheet dismiss) can't swallow this present-while-dismiss.
            DispatchQueue.main.async { celebratingMilestone = milestone }
        } catch {
            // Revert the bump so the milestone can re-fire next time rather than
            // being silently consumed (never celebrated, never re-fires).
            settings.lastCelebratedMilestone = previous
            errorMessage = "Your change couldn't be saved. Please try again."
        }
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

    private func dismissCoaching() {
        guard let settings = settingsList.first else { return }
        settings.coachingDismissed = true
        do {
            try context.save()
        } catch {
            settings.coachingDismissed = false
            errorMessage = "Your change couldn't be saved. Please try again."
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
