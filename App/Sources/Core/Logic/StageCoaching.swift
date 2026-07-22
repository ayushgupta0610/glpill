import Foundation

enum StageCoaching {
    /// One-time, stage-tailored orientation. Timing/logging guidance only — no medical advice. nil = no card.
    static func message(stage: String?, requiresEmptyStomach: Bool) -> String? {
        switch stage {
        case "switchingFromInjections":
            return requiresEmptyStomach
              ? "Switching from a shot? The big change: take this pill on an empty stomach, then wait before eating — we'll time it for you."
              : "Switching from a shot? Just take your pill daily and log it — we'll handle reminders."
        case "aboutToStart": return "Starting soon? Log your first pill the moment you take it — we'll handle the timing and reminders."
        case "firstWeeks": return "The first few weeks are when side effects peak — log how you feel so your doctor report stays accurate."
        default: return nil // "aWhile" or unknown → no card
        }
    }
}
