import Foundation

struct TitrationPosition: Equatable {
    let stepIndex: Int
    let dayWithinStep: Int
    let nextStepDate: Date?
}

enum TitrationProgress {
    /// Where the user is in a chained dose-escalation plan.
    /// Steps run back to back from `planStart`, each `durationWeeks * 7` days long.
    /// Past the final step the position stays on the last step with no next date.
    static func position(
        steps: [(doseMg: Double, durationWeeks: Int)],
        planStart: Date,
        today: Date,
        calendar: Calendar
    ) -> TitrationPosition? {
        guard !steps.isEmpty else { return nil }

        let start = calendar.startOfDay(for: planStart)
        let day = calendar.startOfDay(for: today)
        let elapsed = max(0, calendar.dateComponents([.day], from: start, to: day).day ?? 0)

        var stepStart = 0
        for (index, step) in steps.enumerated() {
            let duration = step.durationWeeks * 7
            let stepEnd = stepStart + duration
            if elapsed < stepEnd {
                let hasNext = index < steps.count - 1
                let nextDate = hasNext ? calendar.date(byAdding: .day, value: stepEnd, to: start) : nil
                return TitrationPosition(stepIndex: index, dayWithinStep: elapsed - stepStart, nextStepDate: nextDate)
            }
            stepStart = stepEnd
        }

        let lastIndex = steps.count - 1
        let lastStart = stepStart - steps[lastIndex].durationWeeks * 7
        return TitrationPosition(stepIndex: lastIndex, dayWithinStep: elapsed - lastStart, nextStepDate: nil)
    }
}
