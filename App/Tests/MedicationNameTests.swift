import Testing
@testable import GLPill

struct MedicationNameTests {
    @Test("Trims surrounding whitespace")
    func trims() {
        #expect(MedicationName.normalize("  Ozempic  ") == "Ozempic")
    }

    @Test("Caps at 40 characters")
    func caps() {
        let long = String(repeating: "a", count: 60)
        #expect(MedicationName.normalize(long)?.count == 40)
    }

    @Test("Returns nil for empty or whitespace-only input")
    func emptyIsNil() {
        #expect(MedicationName.normalize("") == nil)
        #expect(MedicationName.normalize("   ") == nil)
        #expect(MedicationName.normalize("\n\t") == nil)
    }
}
