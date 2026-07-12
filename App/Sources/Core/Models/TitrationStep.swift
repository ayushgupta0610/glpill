import Foundation
import SwiftData

@Model
final class TitrationStep {
    var order: Int
    var doseMg: Double
    var durationWeeks: Int
    var startDate: Date?

    init(order: Int, doseMg: Double, durationWeeks: Int, startDate: Date? = nil) {
        self.order = order
        self.doseMg = doseMg
        self.durationWeeks = durationWeeks
        self.startDate = startDate
    }
}
