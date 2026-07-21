import Foundation

/// A pure, unit-tested description of the user's morning order:
/// pill → (after window) other meds → breakfast. Timing metadata only.
struct MorningSequence {
    struct Step: Equatable {
        let title: String
        let subtitle: String?
        let done: Bool
    }
    static func make(pillTaken: Bool, pillName: String, hadWindow: Bool, clearTime: Date?, meds: [String]) -> [Step] {
        var steps: [Step] = [Step(title: pillName, subtitle: pillTaken ? "Taken" : nil, done: pillTaken)]
        guard pillTaken else { return steps }
        let after: String? = {
            guard hadWindow, let clearTime else { return nil }
            return "After \(clearTime.formatted(date: .omitted, time: .shortened))"
        }()
        for med in meds { steps.append(Step(title: med, subtitle: after ?? "OK now", done: false)) }
        steps.append(Step(title: "Breakfast", subtitle: after ?? "OK now", done: false))
        return steps
    }
}
