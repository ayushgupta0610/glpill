import SwiftUI

struct EatTimerView: View {
    let end: Date

    var body: some View {
        Card {
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
                            Text("until you can eat or drink")
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
            }
        }
    }

    private func timerString(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
