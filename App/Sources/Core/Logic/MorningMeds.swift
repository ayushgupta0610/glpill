import Foundation

/// Pure helpers for the user's optional "other morning meds" list (names only).
/// No dosages, no times, no interaction data — this is timing/reminder metadata,
/// not medical advice.
enum MorningMeds {
    /// Trim whitespace, drop blanks, and dedupe case-insensitively while
    /// preserving first-seen casing and order.
    static func normalize(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in raw {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed.lowercased()).inserted {
                result.append(trimmed)
            }
        }
        return result
    }
}
