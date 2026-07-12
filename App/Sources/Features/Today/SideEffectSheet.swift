import SwiftUI

struct SideEffectSheet: View {
    let onSave: (SideEffectKind, Int, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var kind: SideEffectKind = .nausea
    @State private var severity = 1
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Side effect", selection: $kind) {
                    ForEach(SideEffectKind.allCases, id: \.self) { kind in
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
            }
            .navigationTitle("Log side effect")
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
        }
    }
}
