import SwiftUI
import SwiftData

struct WeightEntrySheet: View {
    let metric: Bool
    var entry: WeightEntry? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightEntry.date, order: .reverse) private var allEntries: [WeightEntry]
    @State private var usesMetric: Bool
    @State private var displayValue: Double?
    @State private var date = Date.now
    @State private var errorMessage: String?
    @State private var showOutlierAlert = false
    @State private var isSaving = false
    @State private var isInitializing = true

    init(metric: Bool, entry: WeightEntry? = nil) {
        self.metric = metric
        self.entry = entry
        // Seed usesMetric from `metric` at init, not in onAppear — assigning it
        // there is a real state change when metric == true, which schedules
        // .onChange(of: usesMetric) to fire on the next run-loop tick, after
        // onAppear has already cleared isInitializing (see Round 2 QA regression).
        _usesMetric = State(initialValue: metric)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Units", selection: $usesMetric) {
                    Text("kg").tag(true)
                    Text("lb").tag(false)
                }
                .pickerStyle(.segmented)
                .onChange(of: usesMetric) { oldMetric, newMetric in
                    // Convert the shown number in place — no data change.
                    guard !isInitializing, let value = displayValue else { return }
                    let kg = UnitFormat.kilograms(fromDisplay: value, metric: oldMetric)
                    displayValue = newMetric ? kg : kg / UnitFormat.kgPerLb
                }

                LabeledContent("Weight (\(usesMetric ? "kg" : "lb"))") {
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
            .navigationTitle(entry == nil ? "Add weigh-in" : "Edit weigh-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { attemptSave() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .alert("Double-check this weigh-in", isPresented: $showOutlierAlert) {
                Button("Save anyway") { persist() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(outlierMessage)
            }
            .onAppear {
                if let entry {
                    displayValue = usesMetric ? entry.kilograms : entry.kilograms / UnitFormat.kgPerLb
                    date = entry.date
                }
                isInitializing = false
            }
        }
    }

    /// The most recent existing weigh-in, excluding the one being edited.
    private var lastKg: Double? {
        allEntries.first { $0.persistentModelID != entry?.persistentModelID }?.kilograms
    }

    private var enteredKilograms: Double? {
        displayValue.map { UnitFormat.kilograms(fromDisplay: $0, metric: usesMetric) }
    }

    private var outlierMessage: String {
        let lastText = lastKg.map { UnitFormat.weightString(kilograms: $0, metric: usesMetric) } ?? "—"
        let otherUnit = usesMetric ? "lb" : "kg"
        return "That's a big jump from your last weigh-in (\(lastText)). Did you mean \(otherUnit)?"
    }

    private func attemptSave() {
        guard let kilograms = enteredKilograms else {
            errorMessage = "Enter your weight first."
            return
        }
        guard UnitFormat.isValidWeight(kilograms: kilograms) else {
            errorMessage = "Please enter a weight between 55–1100 lb (25–500 kg)."
            return
        }
        if WeightOutlier.isSuspicious(newKg: kilograms, lastKg: lastKg) {
            showOutlierAlert = true
            return
        }
        persist()
    }

    private func persist() {
        guard !isSaving else { return }
        isSaving = true
        guard let kilograms = enteredKilograms else { isSaving = false; return }
        if let entry {
            entry.kilograms = kilograms
            entry.date = date
        } else {
            context.insert(WeightEntry(date: date, kilograms: kilograms))
        }
        if let settings = UserSettings.canonical(in: context) {
            settings.usesMetric = usesMetric
        }
        do {
            try context.save()
            dismiss()
        } catch {
            errorMessage = "Couldn't save — please try again."
            isSaving = false
        }
    }
}
