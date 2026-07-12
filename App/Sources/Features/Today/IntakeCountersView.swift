import SwiftUI
import SwiftData

struct IntakeCountersView: View {
    let onProtein: (Int) -> Void
    let onWater: (Int) -> Void

    @Query private var intakeDays: [IntakeDay]
    @Query private var settingsList: [UserSettings]
    @State private var tapPulse = false

    private static let mlPerOz = 29.5735

    private var today: IntakeDay? {
        intakeDays.first { Calendar.current.isDateInToday($0.date) }
    }

    private var metric: Bool { settingsList.first?.usesMetric ?? false }
    private var proteinTarget: Int { settingsList.first?.proteinTargetGrams ?? 100 }
    private var waterTarget: Int { settingsList.first?.waterTargetMl ?? 2000 }

    var body: some View {
        Card {
            SectionHeader(title: "Protein & water")
            Text("Protecting muscle matters on GLP-1s — hit your protein.")
                .font(.caption)
                .foregroundStyle(.secondary)

            counterRow(
                icon: "fork.knife",
                tint: Theme.primary,
                value: today?.proteinGrams ?? 0,
                target: proteinTarget,
                display: { "\($0) g" },
                increments: [(10, "+10"), (25, "+25")],
                unitName: "grams of protein",
                action: onProtein
            )
            counterRow(
                icon: "drop.fill",
                tint: .blue,
                value: today?.waterMl ?? 0,
                target: waterTarget,
                display: { metric ? "\($0) ml" : "\(Int((Double($0) / Self.mlPerOz).rounded())) oz" },
                increments: metric ? [(250, "+250"), (500, "+500")] : [(237, "+8 oz"), (473, "+16 oz")],
                unitName: metric ? "milliliters of water" : "ounces of water",
                action: onWater
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tapPulse)
    }

    private func counterRow(
        icon: String,
        tint: Color,
        value: Int,
        target: Int,
        display: (Int) -> String,
        increments: [(amount: Int, label: String)],
        unitName: String,
        action: @escaping (Int) -> Void
    ) -> some View {
        let targetHit = value >= target
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: targetHit ? "checkmark.circle.fill" : icon)
                    .foregroundStyle(tint)
                Text("\(display(value)) / \(display(target))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if targetHit {
                    Text("Target hit")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint)
                }
                Spacer()
                ForEach(increments, id: \.amount) { increment in
                    Button(increment.label) {
                        tapPulse.toggle()
                        action(increment.amount)
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(tint)
                    .accessibilityLabel("Add \(increment.label.dropFirst()) \(unitName)")
                }
            }
            ProgressView(value: min(Double(value), Double(target)), total: Double(target))
                .tint(tint)
        }
    }
}
