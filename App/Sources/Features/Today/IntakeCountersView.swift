import SwiftUI
import SwiftData

struct IntakeCountersView: View {
    let onProtein: (Int) -> Void
    let onWater: (Int) -> Void

    @Query private var intakeDays: [IntakeDay]
    @Query private var settingsList: [UserSettings]

    private var today: IntakeDay? {
        intakeDays.first { Calendar.current.isDateInToday($0.date) }
    }

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
                unit: "g",
                increments: [10, 25],
                action: onProtein
            )
            counterRow(
                icon: "drop.fill",
                tint: .blue,
                value: today?.waterMl ?? 0,
                target: waterTarget,
                unit: "ml",
                increments: [250, 500],
                action: onWater
            )
        }
    }

    private func counterRow(
        icon: String,
        tint: Color,
        value: Int,
        target: Int,
        unit: String,
        increments: [Int],
        action: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text("\(value) / \(target) \(unit)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Spacer()
                ForEach(increments, id: \.self) { amount in
                    Button("+\(amount)") { action(amount) }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(tint)
                }
            }
            ProgressView(value: min(Double(value), Double(target)), total: Double(target))
                .tint(tint)
        }
    }
}
