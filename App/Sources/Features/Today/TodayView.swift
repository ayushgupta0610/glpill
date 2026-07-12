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

    private var store: TodayStore { TodayStore(context: context) }
    private var calendar: Calendar { .current }

    private var todayLog: DoseLog? {
        doseLogs.first { calendar.isDateInToday($0.date) }
    }

    private var streak: Int {
        StreakCalculator.currentStreak(doseDays: doseLogs.map(\.date), today: .now, calendar: calendar)
    }

    private var eatTimerActive: Bool {
        Date(timeIntervalSince1970: eatTimerEnd) > .now
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    doseCard
                    if eatTimerActive {
                        EatTimerView(end: Date(timeIntervalSince1970: eatTimerEnd))
                    }
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
            .navigationTitle(Date.now.formatted(date: .abbreviated, time: .omitted))
            .sensoryFeedback(.success, trigger: doseJustLogged)
            .sheet(isPresented: $showSideEffectSheet) {
                SideEffectSheet { kind, severity, note in
                    withErrorHandling { try store.logSideEffect(kind, severity: severity, note: note) }
                }
                .presentationDetents([.medium])
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

    private var doseCard: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(medications.first?.displayName ?? "Your GLP-1 pill")
                        .font(.headline)
                    Text(doseSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let log = todayLog {
                Label("Taken at \(log.takenAt.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .symbolEffect(.bounce, value: doseJustLogged)
            } else {
                PillCTAButton(title: "Take today's pill", systemImage: "pills.fill") {
                    takePill()
                }
            }
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
                        Text("Longest: \(StreakCalculator.longestStreak(doseDays: doseLogs.map(\.date), calendar: calendar)) days")
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
        withErrorHandling {
            let startTimer = try store.logDose()
            doseJustLogged.toggle()
            if startTimer {
                eatTimerEnd = Date().addingTimeInterval(30 * 60).timeIntervalSince1970
                ReminderScheduler.scheduleEatTimer(using: UNNotificationScheduler())
            }
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
