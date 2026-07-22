import SwiftUI
import SwiftData

struct MorningMedsEditor: View {
    @Query(sort: \UserSettings.createdAt) private var settingsList: [UserSettings]
    @State private var entry = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Add a medication", text: $entry)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(entry.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("Names only. We use these to tell you when your empty-stomach window is clear. Stored privately on your device.")
            }

            if let settings = settingsList.first, !settings.morningMeds.isEmpty {
                Section {
                    ForEach(Array(settings.morningMeds.enumerated()), id: \.offset) { index, _ in
                        TextField("Medication", text: editBinding(settings: settings, index: index))
                            .onSubmit { commitEdit(settings: settings) }
                    }
                    .onDelete { offsets in
                        var meds = settings.morningMeds
                        meds.remove(atOffsets: offsets)
                        settings.morningMeds = meds
                    }
                }
            }
        }
        .navigationTitle("Morning meds")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add() {
        guard let settings = settingsList.first else { return }
        settings.morningMeds = MorningMeds.normalize(settings.morningMeds + [entry])
        entry = ""
    }

    /// Binding for editing an existing entry in place. Writes the raw typed
    /// text straight through while the user is typing (normalizing on every
    /// keystroke would dedupe/reindex mid-word); `commitEdit` re-normalizes
    /// once editing finishes.
    private func editBinding(settings: UserSettings, index: Int) -> Binding<String> {
        Binding(
            get: {
                guard settings.morningMeds.indices.contains(index) else { return "" }
                return settings.morningMeds[index]
            },
            set: { newValue in
                var meds = settings.morningMeds
                guard meds.indices.contains(index) else { return }
                meds[index] = newValue
                settings.morningMeds = meds
            }
        )
    }

    /// Re-normalizes (trim/dedupe) the list once an in-place edit is done,
    /// same as `add()` does for new entries.
    private func commitEdit(settings: UserSettings) {
        settings.morningMeds = MorningMeds.normalize(settings.morningMeds)
    }
}
