import SwiftUI
import SwiftData

struct MedicationEditor: View {
    @Query(sort: \Medication.createdAt) private var medications: [Medication]
    @State private var customNameDraft = ""
    @AppStorage("eatTimerEnd") private var eatTimerEnd: Double = 0

    /// Cancels a pending "you can eat now" push and clears the in-app eat-window.
    /// Called whenever the medication no longer requires an empty stomach, so the
    /// Toggle and the Picker never diverge.
    private func cancelEatTimer() {
        UNNotificationScheduler().removePending(ids: [ReminderScheduler.eatTimerId])
        eatTimerEnd = 0
    }

    var body: some View {
        Form {
            if let medication = medications.first {
                @Bindable var medication = medication
                Picker("Medication", selection: $medication.kindRaw) {
                    ForEach(MedicationKind.allCases, id: \.rawValue) { kind in
                        Text(kind.defaultDisplayName).tag(kind.rawValue)
                    }
                }
                .onChange(of: medication.kindRaw) {
                    medication.requiresEmptyStomach = medication.kind.defaultRequiresEmptyStomach
                    if !medication.requiresEmptyStomach {
                        cancelEatTimer()
                    }
                }

                if medication.kind == .custom {
                    TextField("Name", text: $customNameDraft)
                        .onChange(of: customNameDraft) { _, value in
                            // Persist the normalized name only when it's non-empty;
                            // keep the last valid name if the field is cleared.
                            if let normalized = MedicationName.normalize(value) {
                                medication.customName = normalized
                            }
                        }
                    if MedicationName.normalize(customNameDraft) == nil {
                        Text("Enter a medication name.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Toggle("Empty stomach + 30-min wait", isOn: $medication.requiresEmptyStomach)
                    .onChange(of: medication.requiresEmptyStomach) { _, requiresEmptyStomach in
                        guard !requiresEmptyStomach else { return }
                        cancelEatTimer()
                    }

                Text("Turn this on if your medication must be taken on an empty stomach (like Rybelsus®). GLPill will run a 30-minute timer after each dose.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .onAppear { customNameDraft = medication.customName ?? "" }
            } else {
                Text("Complete onboarding first.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Medication")
        .navigationBarTitleDisplayMode(.inline)
    }
}
