import SwiftUI
import SwiftData

struct IntakeCountersView: View {
    let onProtein: (Int) -> Void
    let onWater: (Int) -> Void
    let onSetProtein: (Int) -> Void
    let onSetWater: (Int) -> Void

    @Query private var intakeDays: [IntakeDay]
    @Query(sort: \UserSettings.createdAt) private var settingsList: [UserSettings]
    @State private var tapPulse = false
    @State private var editingProtein = false
    @State private var editingWater = false
    @State private var editText = ""
    @State private var inputError: String?

    private static let mlPerOz = 29.5735
    private static let waterTint = Color(red: 0.184, green: 0.498, blue: 0.816) // #2F7FD0

    private var today: IntakeDay? {
        intakeDays.first { Calendar.current.isDateInToday($0.date) }
    }

    private var metric: Bool { settingsList.first?.usesMetric ?? false }
    private var proteinTarget: Int { settingsList.first?.proteinTargetGrams ?? 100 }
    private var waterTarget: Int { settingsList.first?.waterTargetMl ?? 2000 }

    private var proteinValue: Int { today?.proteinGrams ?? 0 }
    private var waterValue: Int { today?.waterMl ?? 0 }

    /// Water step in ml: 50 metric, ~2 oz (59 ml) imperial.
    private var waterStep: Int { metric ? 50 : Int((2 * Self.mlPerOz).rounded()) }

    var body: some View {
        Card {
            SectionHeader(title: "Protein & water")
            Text("Protecting muscle matters on GLP-1s — hit your protein.")
                .font(.caption)
                .foregroundStyle(.secondary)

            counterRow(
                isShaker: true,
                tint: Theme.primary,
                value: proteinValue,
                target: proteinTarget,
                step: 5,
                display: { "\($0) g" },
                unitName: "grams of protein",
                onDelta: onProtein,
                editing: $editingProtein
            )

            Divider()

            counterRow(
                isShaker: false,
                tint: Self.waterTint,
                value: waterValue,
                target: waterTarget,
                step: waterStep,
                display: { metric ? "\($0) ml" : "\(Int((Double($0) / Self.mlPerOz).rounded())) oz" },
                unitName: metric ? "milliliters of water" : "ounces of water",
                onDelta: onWater,
                editing: $editingWater
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tapPulse)
        .alert("Set protein (grams)", isPresented: $editingProtein) {
            TextField("grams", text: $editText)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { inputError = nil }
            // Non-dismissing default keeps the alert open on invalid input so the
            // entry isn't silently discarded.
            Button("Set") {
                guard let grams = IntakeInput.parse(editText) else {
                    inputError = Self.invalidInputMessage
                    editingProtein = true
                    return
                }
                inputError = nil
                onSetProtein(grams)
                tapPulse.toggle()
            }
        } message: {
            if let inputError { Text(inputError) }
        }
        .alert(metric ? "Set water (ml)" : "Set water (oz)", isPresented: $editingWater) {
            TextField(metric ? "ml" : "oz", text: $editText)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { inputError = nil }
            Button("Set") {
                guard let entered = IntakeInput.parse(editText) else {
                    inputError = Self.invalidInputMessage
                    editingWater = true
                    return
                }
                let ml: Int
                if metric {
                    ml = entered
                } else {
                    // Cap the oz→ml converted value before it can overflow Int64.
                    let converted = (Double(entered) * Self.mlPerOz).rounded()
                    guard converted.isFinite, converted <= IntakeInput.maxValue else {
                        inputError = Self.invalidInputMessage
                        editingWater = true
                        return
                    }
                    ml = Int(converted)
                }
                inputError = nil
                onSetWater(ml)
                tapPulse.toggle()
            }
        } message: {
            if let inputError { Text(inputError) }
        }
    }

    private static let invalidInputMessage = "Enter a number between 0 and 100000."

    private func counterRow(
        isShaker: Bool,
        tint: Color,
        value: Int,
        target: Int,
        step: Int,
        display: (Int) -> String,
        unitName: String,
        onDelta: @escaping (Int) -> Void,
        editing: Binding<Bool>
    ) -> some View {
        let targetHit = value >= target
        let fraction = target > 0 ? Double(value) / Double(target) : 0
        return HStack(alignment: .center, spacing: 14) {
            IntakeVessel(fraction: fraction, tint: tint, isShaker: isShaker)

            VStack(alignment: .leading, spacing: 6) {
                // Current total is the tap target for exact entry.
                HStack(spacing: 6) {
                    if targetHit {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(tint)
                    }
                    Button {
                        editText = ""
                        inputError = nil
                        editing.wrappedValue = true
                    } label: {
                        Text(display(value))
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Current \(unitName): \(display(value)). Tap to type an exact value.")
                    Text("/ \(display(target))")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if targetHit {
                        Text("Target hit")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(tint)
                    }
                }

                // Stepper: − [step size] +. The middle shows how much each tap changes.
                HStack(spacing: 12) {
                    Button {
                        tapPulse.toggle()
                        onDelta(-step)
                    } label: {
                        Image(systemName: "minus")
                            .font(.headline)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .accessibilityLabel("Subtract \(display(step))")

                    Text(display(step))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .frame(minWidth: 64)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Step size \(display(step))")

                    Button {
                        tapPulse.toggle()
                        onDelta(step)
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(tint)
                    .accessibilityLabel("Add \(display(step))")
                }

                Text("Tap the total above to enter an exact amount")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ProgressView(value: min(Double(value), Double(target)), total: Double(max(target, 1)))
                    .tint(tint)
            }
        }
        .padding(.vertical, 4)
    }
}
