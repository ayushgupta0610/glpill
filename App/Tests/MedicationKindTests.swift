import Testing
@testable import GLPill

struct MedicationKindTests {
    @Test("Wegovy pill requires an empty stomach")
    func wegovyPillEmptyStomach() {
        #expect(MedicationKind.wegovyPill.defaultRequiresEmptyStomach == true)
        #expect(MedicationKind.wegovyPill.defaultDisplayName == "Wegovy pill (oral semaglutide)")
    }
    @Test("Foundayo has no empty-stomach rule")
    func foundayoNoWindow() { #expect(MedicationKind.foundayo.defaultRequiresEmptyStomach == false) }
}
