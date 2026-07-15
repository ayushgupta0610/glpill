import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var context
    @State private var store = OnboardingStore()
    @State private var step = 0
    @State private var errorMessage: String?

    private let totalSteps = 5

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
            case 1: MedicationStep(store: store, next: advance)
            case 2: TitrationSetupStep(store: store, next: advance)
            case 3: WeightStep(store: store, next: advance)
            default: ReminderStep(store: store, finish: complete)
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
        step += 1
    }

    private func complete() {
        do {
            try store.complete(in: context)
            let hour = store.reminderHour
            let minute = store.reminderMinute
            Task {
                let scheduler = UNNotificationScheduler()
                if await scheduler.requestAuthorization() {
                    ReminderScheduler.scheduleDaily(hour: hour, minute: minute, using: scheduler)
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
            Text("Make every pill count")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Built for Foundayo®, Rybelsus® and daily GLP-1 pills — not injections.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            VStack(alignment: .leading, spacing: 12) {
                bullet("checkmark.circle.fill", "One-tap daily pill tracking with streaks")
                bullet("chart.line.uptrend.xyaxis", "Weight trend and milestones")
                bullet("clock.fill", "Empty-stomach timer for Rybelsus®")
                bullet("doc.text.fill", "A summary your doctor will love")
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
                .padding(.bottom, 24)
        }
        .padding(.horizontal)
        .background(Color(.systemGroupedBackground))
    }
}

private struct TitrationSetupStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your dose plan")
                .font(.title.bold())
                .padding(.top, 24)
            Text("Enter the dose steps your prescriber gave you. You can change this anytime in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List {
                ForEach($store.steps) { $draft in
                    HStack {
                        TextField("Dose", value: Binding(
                            get: { draft.doseMg },
                            set: { draft.doseMg = min(max($0, 0.05), 50) }
                        ), format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 64)
                        Text("mg")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Stepper("\(draft.durationWeeks) wk", value: $draft.durationWeeks, in: 1...52)
                            .fixedSize()
                    }
                }
                .onDelete { store.steps.remove(atOffsets: $0) }

                Button {
                    // Prefill with the previous dose unchanged — GLPill never suggests escalations.
                    let last = store.steps.last
                    store.steps.append(OnboardingStore.DraftStep(
                        doseMg: last?.doseMg ?? 0.8,
                        durationWeeks: last?.durationWeeks ?? 4
                    ))
                } label: {
                    Label("Add step", systemImage: "plus.circle.fill")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            PillCTAButton(title: "Continue", systemImage: "arrow.right") { next() }
                .padding(.bottom, 24)
        }
        .padding(.horizontal)
        .background(Color(.systemGroupedBackground))
    }
}

private struct WeightStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Where are you starting?")
                .font(.title.bold())
                .padding(.top, 24)

            Picker("Units", selection: $store.usesMetric) {
                Text("lb").tag(false)
                Text("kg").tag(true)
            }
            .pickerStyle(.segmented)

            LabeledContent("Current weight") {
                TextField("0", value: $store.displayWeight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))

            LabeledContent("Goal weight (optional)") {
                TextField("0", value: $store.displayGoal, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))

            Text("Synced privately through your own iCloud. GLPill has no servers and never sees your data.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
            PillCTAButton(title: "Continue", systemImage: "arrow.right") { next() }
                .padding(.bottom, 24)
        }
        .padding(.horizontal)
        .background(Color(.systemGroupedBackground))
    }
}

private struct ReminderStep: View {
    @Bindable var store: OnboardingStore
    let finish: () -> Void
    @State private var time = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? .now

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily reminder")
                .font(.title.bold())
                .padding(.top, 24)
                .task {
                    // Ask here so the system dialog never lands on top of the paywall.
                    _ = await UNNotificationScheduler().requestAuthorization()
                }
            Text("Consistency is everything with a daily pill. When should we nudge you?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            DatePicker("Reminder time", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

            Spacer()
            PillCTAButton(title: "Finish setup", systemImage: "checkmark") {
                let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                store.reminderHour = components.hour ?? 9
                store.reminderMinute = components.minute ?? 0
                finish()
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal)
        .background(Color(.systemGroupedBackground))
    }
}
