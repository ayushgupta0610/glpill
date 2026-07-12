import Foundation
import SwiftData

@Model
final class DoseLog {
    /// Day-normalized date (start of day) the dose belongs to.
    var date: Date
    var takenAt: Date
    var doseMg: Double

    init(date: Date, takenAt: Date, doseMg: Double) {
        self.date = date
        self.takenAt = takenAt
        self.doseMg = doseMg
    }
}
