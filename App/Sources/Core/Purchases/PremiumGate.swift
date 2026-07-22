/// Gates premium-only surfaces. Free features never call this. When locked (or
/// unknown), tapping a gated control presents the paywall instead of running the action.
enum PremiumGate {
    static func shouldShowUpgrade(for state: EntitlementState) -> Bool { state != .active }
}
