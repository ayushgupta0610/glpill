import Testing
@testable import GLPill

struct MilestoneTierTests {
    @Test("emoji maps each threshold to its tier")
    func emojiPerThreshold() {
        #expect(MilestoneTier.emoji(for: 7) == "🌱")
        #expect(MilestoneTier.emoji(for: 30) == "🔥")
        #expect(MilestoneTier.emoji(for: 100) == "🏆")
        #expect(MilestoneTier.emoji(for: 365) == "👑")
    }

    @Test("particleCount is monotonic non-decreasing across thresholds")
    func particleCountMonotonic() {
        let counts = [7, 30, 100, 365].map(MilestoneTier.particleCount(for:))
        for pair in zip(counts, counts.dropFirst()) {
            #expect(pair.0 <= pair.1)
        }
    }
}
