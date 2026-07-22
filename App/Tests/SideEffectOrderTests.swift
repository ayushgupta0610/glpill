import Testing
@testable import GLPill

struct SideEffectOrderTests {
    @Test("Concerns lead the list in concern order")
    func concernsLead() {
        let out = SideEffectOrder.ordered(concerns: ["constipation", "nausea"])
        #expect(Array(out.prefix(2)) == [.constipation, .nausea])
    }

    @Test("Unknown, reflux and none concerns are ignored")
    func unmappedIgnored() {
        let out = SideEffectOrder.ordered(concerns: ["reflux", "none", "bogus"])
        #expect(out == SideEffectKind.allCases)
    }

    @Test("Result contains every kind exactly once")
    func everyKindOnce() {
        let out = SideEffectOrder.ordered(concerns: ["constipation", "nausea", "lowAppetite", "fatigue"])
        #expect(out.count == SideEffectKind.allCases.count)
        for kind in SideEffectKind.allCases {
            #expect(out.filter { $0 == kind }.count == 1)
        }
    }
}
