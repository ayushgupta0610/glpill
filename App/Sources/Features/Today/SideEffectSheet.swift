import SwiftUI
import SwiftData

struct SideEffectSheet: View {
    var existing: SideEffectLog? = nil
    let onSave: (SideEffectKind, Int, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserSettings.createdAt) private var settingsList: [UserSettings]
    @State private var kind: SideEffectKind = .nausea
    @State private var severity = 1
    @State private var note = ""

    private static let noteCharacterLimit = 280

    var body: some View {
        NavigationStack {
            Form {
                Picker("Side effect", selection: $kind) {
                    ForEach(SideEffectOrder.ordered(concerns: settingsList.first?.sideEffectConcerns ?? []), id: \.self) { kind in
                        Text("\(kind.emoji) \(kind.label)").tag(kind)
                    }
                }
                Picker("Severity", selection: $severity) {
                    Text("Mild").tag(1)
                    Text("Moderate").tag(2)
                    Text("Severe").tag(3)
                }
                .pickerStyle(.segmented)
                TextField("Note (optional)", text: $note)
                    .onChange(of: note) { _, newValue in
                        if newValue.count > Self.noteCharacterLimit {
                            note = String(newValue.prefix(Self.noteCharacterLimit))
                        }
                    }
            }
            .navigationTitle(existing == nil ? "Log side effect" : "Edit side effect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(kind, severity, note.isEmpty ? nil : note)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .onAppear {
                guard let existing else { return }
                kind = existing.kind
                severity = existing.severity
                note = existing.note ?? ""
            }
        }
    }
}
