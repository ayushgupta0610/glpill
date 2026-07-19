import SwiftUI
import SwiftData

struct MorningMedsEditor: View {
    @Query private var settingsList: [UserSettings]
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
                    ForEach(settings.morningMeds, id: \.self) { med in
                        Text(med)
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
}
