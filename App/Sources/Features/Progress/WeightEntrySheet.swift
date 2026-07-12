import SwiftUI
import SwiftData

struct WeightEntrySheet: View {
    let metric: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var displayValue: Double?
    @State private var date = Date.now
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Weight (\(metric ? "kg" : "lb"))") {
                    TextField("0", value: $displayValue, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Add weigh-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }

    private func save() {
        guard let displayValue else {
            errorMessage = "Enter your weight first."
            return
        }
        let kilograms = UnitFormat.kilograms(fromDisplay: displayValue, metric: metric)
        guard UnitFormat.isValidWeight(kilograms: kilograms) else {
            errorMessage = "Please enter a weight between 55–1100 lb (25–500 kg)."
            return
        }
        context.insert(WeightEntry(date: date, kilograms: kilograms))
        do {
            try context.save()
            dismiss()
        } catch {
            errorMessage = "Couldn't save — please try again."
        }
    }
}
