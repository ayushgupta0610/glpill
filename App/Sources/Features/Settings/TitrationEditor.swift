import SwiftUI
import SwiftData

struct TitrationEditor: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TitrationStep.order) private var steps: [TitrationStep]
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(steps) { step in
                    HStack {
                        TextField("Dose", value: doseBinding(step), format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 64)
                        Text("mg")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Stepper("\(step.durationWeeks) wk", value: Binding(
                            get: { step.durationWeeks },
                            set: { step.durationWeeks = $0 }
                        ), in: 1...52)
                            .fixedSize()
                    }
                }
                .onDelete(perform: deleteSteps)

                Button {
                    addStep()
                } label: {
                    Label("Add step", systemImage: "plus.circle.fill")
                }
            } footer: {
                Text("Enter the plan exactly as your prescriber gave it. Steps run back to back from your start date. This is your record — GLPill never suggests doses.")
            }
        }
        .navigationTitle("Dose plan")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't save", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// Binding that accepts the raw typed dose and validates on commit —
    /// out-of-range values surface an error instead of being silently clamped.
    private func doseBinding(_ step: TitrationStep) -> Binding<Double> {
        Binding(
            get: { step.doseMg },
            set: { newValue in
                guard UnitFormat.isValidDose(mg: newValue) else {
                    errorMessage = "Dose steps must be between 0.05 and 50 mg."
                    return
                }
                step.doseMg = newValue
                saveOrReport()
            }
        )
    }

    private func addStep() {
        // Prefill with the previous dose unchanged — GLPill never suggests escalations.
        let last = steps.last
        context.insert(TitrationStep(
            order: (last?.order ?? -1) + 1,
            doseMg: last?.doseMg ?? 0.8,
            durationWeeks: last?.durationWeeks ?? 4
        ))
        saveOrReport()
    }

    private func deleteSteps(at offsets: IndexSet) {
        for index in offsets {
            context.delete(steps[index])
        }
        saveOrReport()
    }

    private func saveOrReport() {
        do {
            try context.save()
        } catch {
            errorMessage = "Your change couldn't be saved. Please try again."
        }
    }
}
