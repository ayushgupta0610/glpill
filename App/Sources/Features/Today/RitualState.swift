import Foundation

/// The Today tab's hero ("morning ritual") state, derived purely from existing
/// signals — never persisted. Rybelsus (empty stomach) runs a 30-min window;
/// orforglipron/Foundayo has no window.
enum RitualState: Equatable {
    case notTaken(requiresEmptyStomach: Bool)
    case windowRunning(end: Date, meds: [String])
    case clear(meds: [String], hadWindow: Bool)

    static func make(todayLogged: Bool, requiresEmptyStomach: Bool, windowEnd: Date?, meds: [String], now: Date) -> RitualState {
        guard todayLogged else { return .notTaken(requiresEmptyStomach: requiresEmptyStomach) }
        guard requiresEmptyStomach, let end = windowEnd else { return .clear(meds: meds, hadWindow: false) }
        return now < end ? .windowRunning(end: end, meds: meds) : .clear(meds: meds, hadWindow: true)
    }

    /// User-facing headline for the cleared state. The `hadWindow == false` copy keeps
    /// the orforglipron "no empty-stomach window" contrast — the pill-native wedge.
    static func clearMessage(hadWindow: Bool) -> String {
        hadWindow ? "You're clear — you can eat now" : "Logged — no empty-stomach window"
    }
}
