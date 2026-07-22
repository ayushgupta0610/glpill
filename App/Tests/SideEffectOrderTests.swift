import Testing
@testable import GLPill

struct SideEffectOrderTests {
    @Test("Concerns lead the list in concern order")
    func concernsLead() {
        let out = SideEffectOrder.ordered(concerns: ["constipation", "nausea"])
        #expect(Array(out.prefix(2)) == [.constipation, .nausea])
    }

    @Test("Unknown and none concerns are ignored")
    func unmappedIgnored() {
        let out = SideEffectOrder.ordered(concerns: ["none", "bogus"])
        #expect(out == SideEffectKind.allCases)
    }

    @Test("Reflux concern leads the list")
    func refluxLeads() {
        let out = SideEffectOrder.ordered(concerns: ["reflux"])
        #expect(out.first == .reflux)
        #expect(out.count == SideEffectKind.allCases.count)
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
