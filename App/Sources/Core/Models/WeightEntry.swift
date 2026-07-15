import Foundation
import SwiftData

@Model
final class WeightEntry {
    var date: Date = Date.now
    var kilograms: Double = 0

    init(date: Date, kilograms: Double) {
        self.date = date
        self.kilograms = kilograms
    }
}
