import SwiftUI

/// Gates premium-only surfaces. Free features never call this. When locked (or
/// unknown), tapping a gated control presents the paywall instead of running the action.
enum PremiumGate {
    static func shouldShowUpgrade(for state: EntitlementState) -> Bool { state != .active }
}

private struct PremiumTapModifier: ViewModifier {
    @Environment(SubscriptionStore.self) private var subscriptions
    @State private var showPaywall = false
    let action: () -> Void
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if PremiumGate.shouldShowUpgrade(for: subscriptions.state) { showPaywall = true }
                else { action() }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}
extension View {
    /// Runs `action` when the user is premium; otherwise presents the paywall.
    func premiumAction(_ action: @escaping () -> Void) -> some View { modifier(PremiumTapModifier(action: action)) }
}
