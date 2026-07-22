import SwiftUI

/// The shareable 9:16 "Consistency Wrapped" card. Celebrates identity + consistency
/// only — the medication, dose, and (unless opted in) weight never appear.
struct WrappedCardView: View {
    let recap: MonthlyRecap
    var metric: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "pills.fill")
                Text("GLPill").font(.headline.bold())
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.9))

            Spacer(minLength: 12)

            Text(titleLine)
                .font(.subheadline.weight(.bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.bottom, 4)

            Text(recap.archetype.emoji).font(.system(size: 68))
            Text(recap.archetype.title)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Text(recap.archetype.subtitle)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 8)

            Spacer(minLength: 20)

            VStack(spacing: 2) {
                Text("\(recap.currentStreak)")
                    .font(.system(size: 88, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(recap.currentStreak == 1 ? "day streak" : "day streak")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer(minLength: 16)

            VStack(spacing: 8) {
                pill("Showed up \(recap.daysLogged) of \(recap.daysElapsed) days")
                pill("\(recap.consistencyPercent)% consistent")
                if let nsv = recap.nonScaleVictory, !nsv.isEmpty {
                    pill("✨ \(nsv)")
                }
                if let text = weightText {
                    pill(text)
                }
            }

            Spacer(minLength: 12)

            Text("glpillapp.com")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(28)
        .frame(width: 360, height: 640)
        .background(Theme.heroGradient)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = ["\(titleLine) recap.",
                     "\(recap.archetype.title). \(recap.archetype.subtitle)",
                     "\(recap.currentStreak) day streak.",
                     "Showed up \(recap.daysLogged) of \(recap.daysElapsed) days.",
                     "\(recap.consistencyPercent)% consistent."]
        if let nsv = recap.nonScaleVictory, !nsv.isEmpty { parts.append(nsv + ".") }
        if let text = weightText { parts.append(text + ".") }
        return parts.joined(separator: " ")
    }

    private var titleLine: String {
        if let name = recap.firstName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return "\(name)'s \(recap.monthName)".uppercased()
        }
        return recap.monthName.uppercased()
    }

    private var weightText: String? {
        guard let kg = recap.weightChangeKg else { return nil }
        let value = metric ? kg : kg / UnitFormat.kgPerLb
        return String(format: "%+.1f %@ this month", value, metric ? "kg" : "lb")
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.white.opacity(0.18), in: Capsule())
    }
}
