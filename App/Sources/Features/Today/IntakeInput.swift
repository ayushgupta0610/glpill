import Foundation

/// Pure, locale-aware parser for tap-to-type intake entry. Kept separate from the
/// view so the parsing rules (locale decimal, finite/non-negative, sane cap) are
/// unit-testable and crash-free before the value is turned into an `Int`.
enum IntakeInput {
    /// Largest value we accept for a single manual entry. Guards against
    /// `Int(1e30)` / `Int(.infinity)` traps and downstream oz→ml overflow.
    static let maxValue = 100_000.0

    /// Parses user text into a non-negative rounded `Int`, or `nil` when the input
    /// is empty, unparseable, negative, non-finite, or above `maxValue`.
    ///
    /// Locale-aware: honors comma-decimal locales (e.g. "2,5" → 3 in de_DE) via a
    /// `NumberFormatter`, falling back to locale-independent `Double(_:)`.
    static func parse(_ text: String, locale: Locale = .current) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale

        let value = formatter.number(from: trimmed)?.doubleValue ?? Double(trimmed)
        guard let value, value.isFinite, value >= 0, value <= maxValue else { return nil }
        return Int(value.rounded())
    }
}
