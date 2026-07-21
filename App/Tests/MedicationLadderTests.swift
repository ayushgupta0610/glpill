import Testing
@testable import GLPill

struct MedicationLadderTests {
    @Test("Rybelsus ladder is 3, 7, 14")
    func rybelsus() { #expect(MedicationLadder.doses(for: .rybelsus) == [3, 7, 14]) }
    @Test("Foundayo ladder matches the FDA titration")
    func foundayo() { #expect(MedicationLadder.doses(for: .foundayo) == [0.8, 2.5, 5.5, 9, 14.5, 17.2]) }
    @Test("Wegovy pill ladder is 1.5, 4, 9, 25")
    func wegovy() { #expect(MedicationLadder.doses(for: .wegovyPill) == [1.5, 4, 9, 25]) }
    @Test("Custom has no preset ladder")
    func custom() { #expect(MedicationLadder.doses(for: .custom).isEmpty) }
}
