import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var context
    @State private var store = OnboardingStore()
    @State private var step = 0
    @State private var errorMessage: String?

    private let totalSteps = 11

    var body: some View {
        VStack(spacing: 0) {
            if step > 0 {
                ProgressView(value: Double(step + 1), total: Double(totalSteps))
                    .tint(Theme.primary)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

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
        }
        .animation(.snappy, value: step)
        .alert("Something's off", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func advance() {
        if step == 4 && !store.requiresEmptyStomach { step += 2 } else { step += 1 }
    }

    private func complete() {
        do {
            try store.complete(in: context)
            let hour = store.reminderHour
            let minute = store.reminderMinute
            if store.reminderStyle != "none" {
                Task {
                    let scheduler = UNNotificationScheduler()
                    if await scheduler.requestAuthorization() {
                        ReminderScheduler.scheduleDaily(hour: hour, minute: minute, using: scheduler)
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct WelcomeStep: View {
    let next: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "pills.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white)
                .frame(width: 120, height: 120)
                .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 28))
            Text("The calm daily co-pilot for the GLP-1 pill")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Take it right, remember your other morning meds, and watch steady progress — without the weight-loss noise.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            VStack(alignment: .leading, spacing: 12) {
                bullet("checkmark.circle.fill", "One-tap daily pill tracking with streaks")
                bullet("chart.line.uptrend.xyaxis", "Weight trend and milestones")
                bullet("clock.fill", "Empty-stomach timer for Rybelsus®")
                bullet("doc.text.fill", "A summary your doctor will love")
                bullet("lock.fill", "Private by design — no account, no servers")
            }
            .padding(.horizontal)
            Spacer()
            Text("GLPill is a tracking tool, not medical advice. Always follow your prescriber's instructions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            PillCTAButton(title: "Get started", systemImage: "arrow.right") { next() }
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.primary)
            Text(text)
                .font(.subheadline)
        }
    }
}

private struct MedicationStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Which pill are you on?")
                .font(.title.bold())
                .padding(.top, 24)

            ForEach(MedicationKind.allCases, id: \.self) { kind in
                Button {
                    store.kind = kind
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.defaultDisplayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if kind == .rybelsus {
                                Text("Empty stomach + 30-min wait — we'll time it for you")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if kind == .wegovyPill {
                                Text("Empty stomach + 30-min wait — we'll time it for you")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if kind == .foundayo {
                                Text("No food or water rules — take it any time of day")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: store.kind == kind ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(store.kind == kind ? Theme.primary : Color.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                            .stroke(store.kind == kind ? Theme.primary : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }

            if store.kind == .custom {
                TextField("Medication name", text: $store.customName)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()
            PillCTAButton(title: "Continue", systemImage: "arrow.right") { next() }
                .disabled(store.kind == .custom && MedicationName.normalize(store.customName) == nil)
                .padding(.bottom, 24)
        }
        .padding(.horizontal)
        .background(Color(.systemGroupedBackground))
    }
}
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
