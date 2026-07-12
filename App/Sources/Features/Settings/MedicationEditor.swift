import SwiftUI
import SwiftData

struct MedicationEditor: View {
    @Query private var medications: [Medication]

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
                }

                if medication.kind == .custom {
                    TextField("Name", text: .init(
                        get: { medication.customName ?? "" },
                        set: { medication.customName = $0 }
                    ))
                }

                Toggle("Empty stomach + 30-min wait", isOn: $medication.requiresEmptyStomach)

                Text("Turn this on if your medication must be taken on an empty stomach (like Rybelsus®). GLPill will run a 30-minute timer after each dose.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Complete onboarding first.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Medication")
        .navigationBarTitleDisplayMode(.inline)
    }
}
