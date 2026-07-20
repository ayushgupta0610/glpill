import SwiftUI

struct EatTimerView: View {
    let end: Date

    // Renders card-less; embedded inside RitualCard's Card (its only caller).
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = max(0, end.timeIntervalSince(timeline.date))
            HStack(spacing: 16) {
                Image(systemName: remaining > 0 ? "clock.fill" : "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(remaining > 0 ? Theme.warn : Theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    if remaining > 0 {
                        Text(timerString(remaining))
                            .font(.title2.bold())
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("You can eat at \(end.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("You can eat now")
                            .font(.title3.bold())
                        Text("30 minutes are up — enjoy your meal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func timerString(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
