import Testing
import Foundation
@testable import GLPill

struct IntakeInputTests {
    @Test("rounds a decimal value")
    func rounds() {
        #expect(IntakeInput.parse("2.5", locale: Locale(identifier: "en_US")) == 3)
    }

    @Test("comma-decimal locale parses fractional input")
    func commaLocale() {
        #expect(IntakeInput.parse("2,5", locale: Locale(identifier: "de_DE")) == 3)
    }

    @Test("huge exponent value is rejected (would trap Int)")
    func hugeValue() {
        #expect(IntakeInput.parse("1e30", locale: Locale(identifier: "en_US")) == nil)
    }

    @Test("infinity is rejected")
    func infinity() {
        #expect(IntakeInput.parse("inf", locale: Locale(identifier: "en_US")) == nil)
    }

    @Test("negative is rejected")
    func negative() {
        #expect(IntakeInput.parse("-5", locale: Locale(identifier: "en_US")) == nil)
    }

    @Test("empty is rejected")
    func empty() {
        #expect(IntakeInput.parse("", locale: Locale(identifier: "en_US")) == nil)
    }

    @Test("value over the cap is rejected")
    func overCap() {
        #expect(IntakeInput.parse("99999999", locale: Locale(identifier: "en_US")) == nil)
    }

    @Test("value at the cap is accepted")
    func atCap() {
        #expect(IntakeInput.parse("100000", locale: Locale(identifier: "en_US")) == 100_000)
    }
}
