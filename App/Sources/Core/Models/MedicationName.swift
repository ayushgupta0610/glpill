import Foundation

/// Normalizes a user-entered custom medication name: trims surrounding
/// whitespace, caps at 40 characters, and returns nil when nothing is left.
enum MedicationName {
    static let maxLength = 40

    static func normalize(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }
}
