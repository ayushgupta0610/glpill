import Foundation
import SwiftData

@Model
final class WeightEntry {
    var date: Date
    var kilograms: Double

    init(date: Date, kilograms: Double) {
        self.date = date
        self.kilograms = kilograms
    }
}
