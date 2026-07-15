import Foundation
import SwiftData

@Model
final class IntakeDay {
    /// Day-normalized date (start of day).
    var date: Date = Date.now
    var proteinGrams: Int = 0
    var waterMl: Int = 0

    init(date: Date, proteinGrams: Int = 0, waterMl: Int = 0) {
        self.date = date
        self.proteinGrams = proteinGrams
        self.waterMl = waterMl
    }
}
