import Testing
@testable import GLPill

struct PremiumGateTests {
    @Test("Locked hides premium content and shows the upgrade")
    func locked() { #expect(PremiumGate.shouldShowUpgrade(for: .locked) == true) }
    @Test("Active reveals premium content")
    func active() { #expect(PremiumGate.shouldShowUpgrade(for: .active) == false) }
    @Test("Unknown is treated as locked (fail closed)")
    func unknown() { #expect(PremiumGate.shouldShowUpgrade(for: .unknown) == true) }
}
