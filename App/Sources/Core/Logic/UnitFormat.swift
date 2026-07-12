import Foundation

enum UnitFormat {
    static let kgPerLb = 0.45359237

    static func weightString(kilograms: Double, metric: Bool) -> String {
        if metric {
            return String(format: "%.1f kg", kilograms)
        }
        return String(format: "%.1f lb", kilograms / kgPerLb)
    }

    /// Converts a user-entered display value (kg or lb) to kilograms.
    static func kilograms(fromDisplay value: Double, metric: Bool) -> Double {
        metric ? value : value * kgPerLb
    }

    static func isValidWeight(kilograms: Double) -> Bool {
        (25.0...500.0).contains(kilograms)
    }

    /// Clinically plausible oral GLP-1 dose range (Rybelsus 3–14 mg,
    /// orforglipron up to 36 mg; margin for compounded formulations).
    static func isValidDose(mg: Double) -> Bool {
        (0.05...50.0).contains(mg)
    }
}
