import Foundation
import SwiftData

@Model
final class DoseLog {
    /// Day-normalized date (start of day) the dose belongs to.
    var date: Date = Date.now
    var takenAt: Date = Date.now
    var doseMg: Double = 0

    init(date: Date, takenAt: Date, doseMg: Double) {
        self.date = date
        self.takenAt = takenAt
        self.doseMg = doseMg
    }
}
