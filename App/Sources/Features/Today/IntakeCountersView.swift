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

    private func waterDisplay(_ ml: Int) -> String {
        metric ? "\(ml) ml" : "\(Int((Double(ml) / Self.mlPerOz).rounded())) oz"
    }

    var body: some View {
        Card {
            SectionHeader(title: "Protein & water")
            Text("Protecting muscle matters on GLP-1s — hit your protein.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Grid so labels, visuals, targets, and steppers line up row-by-row
            // across both columns.
            Grid(horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    columnHeader(icon: "fork.knife", title: "Protein", tint: Theme.primary,
                                 hit: proteinValue >= proteinTarget)
                    columnHeader(icon: "drop.fill", title: "Water", tint: .blue,
                                 hit: waterValue >= waterTarget)
                }
                GridRow {
                    proteinRing
                    waterGlass
                }
                GridRow {
                    targetCaption("of \(proteinTarget) g")
                    targetCaption("of \(waterDisplay(waterTarget))")
                }
                GridRow {
                    stepper(tint: Theme.primary, step: 5, stepLabel: "5 g",
                            unit: "grams of protein", onDelta: onProtein)
                    stepper(tint: .blue, step: waterStep, stepLabel: metric ? "50 ml" : "8 oz",
                            unit: metric ? "milliliters of water" : "ounces of water", onDelta: onWater)
                }
            }
            .padding(.top, 4)
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

    // MARK: - Grid cells

    private var proteinRing: some View {
        let fraction = proteinTarget > 0 ? Double(proteinValue) / Double(proteinTarget) : 0
        return Button {
            editText = ""
            inputError = nil
            editingProtein = true
        } label: {
            ProteinRingView(fraction: fraction, tint: Theme.primary, label: "\(proteinValue) g")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Protein \(proteinValue) of \(proteinTarget) grams. Tap to type an exact value.")
    }

    private var waterGlass: some View {
        let fraction = waterTarget > 0 ? Double(waterValue) / Double(waterTarget) : 0
        return Button {
            editText = ""
            inputError = nil
            editingWater = true
        } label: {
            WaterGlassView(fraction: fraction, label: waterDisplay(waterValue))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Water \(waterDisplay(waterValue)) of \(waterDisplay(waterTarget)). Tap to type an exact value.")
    }

    private func targetCaption(_ text: String) -> some View {
        Text(text)
            .font(.caption2).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Shared pieces

    private func columnHeader(icon: String, title: String, tint: Color, hit: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: hit ? "checkmark.circle.fill" : icon)
                .font(.subheadline).foregroundStyle(tint)
            Text(title).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepper(tint: Color, step: Int, stepLabel: String, unit: String,
                         onDelta: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 10) {
            Button {
                tapPulse.toggle()
                onDelta(-step)
            } label: {
                Image(systemName: "minus").font(.headline).frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered).tint(.secondary)
            .accessibilityLabel("Subtract \(stepLabel)")

            Text(stepLabel)
                .font(.subheadline.weight(.bold)).monospacedDigit()
                .frame(minWidth: 44).foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Button {
                tapPulse.toggle()
                onDelta(step)
            } label: {
                Image(systemName: "plus").font(.headline).frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered).tint(tint)
            .accessibilityLabel("Add \(stepLabel)")
        }
        .frame(maxWidth: .infinity)
    }
}
