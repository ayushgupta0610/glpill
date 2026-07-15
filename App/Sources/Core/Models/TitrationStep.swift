import Foundation
import SwiftData

@Model
final class TitrationStep {
    var order: Int = 0
    var doseMg: Double = 0
    var durationWeeks: Int = 1
    var startDate: Date?

    init(order: Int, doseMg: Double, durationWeeks: Int, startDate: Date? = nil) {
        self.order = order
        self.doseMg = doseMg
        self.durationWeeks = durationWeeks
        self.startDate = startDate
    }
}
