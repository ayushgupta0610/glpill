import SwiftUI

/// The Today tab's hero. Renders the pill ritual for the current `RitualState`.
struct RitualCard: View {
    let medName: String
    let doseSubtitle: String
    let state: RitualState
    let takePill: () -> Void
    var undo: (() -> Void)? = nil
    @State private var showExplainer = false

    var body: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(medName).font(.headline)
                    Text(doseSubtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }

            switch state {
            case let .notTaken(requiresEmptyStomach):
                if requiresEmptyStomach {
                    HStack(spacing: 6) {
                        Text("Empty stomach · plain water · then wait 30 min")
                            .font(.caption).foregroundStyle(.secondary)
                        Button { showExplainer = true } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel("Why the 30-minute window?")
                    }
                } else {
                    Text("No timing rules — take it with or without food.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                PillCTAButton(title: "Take today's pill", systemImage: "pills.fill", action: takePill)

            case let .windowRunning(end, meds):
                EatTimerView(end: end)
                if !meds.isEmpty {
                    Label("Other morning meds — after \(end.formatted(date: .omitted, time: .shortened))",
                          systemImage: "clock.badge.checkmark")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let undo {
                    Button("Undo", role: .destructive, action: undo)
                        .font(.caption.weight(.medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }

            case let .clear(meds, hadWindow):
                Label(RitualState.clearMessage(hadWindow: hadWindow),
                      systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                if !meds.isEmpty {
                    Text(hadWindow
                         ? "You can take your \(meds.joined(separator: ", ")) now."
                         : "You can take your \(meds.joined(separator: ", ")) any time.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let undo {
                    Button("Undo", role: .destructive, action: undo)
                        .font(.caption.weight(.medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showExplainer) { RitualExplainerView() }
    }
}
