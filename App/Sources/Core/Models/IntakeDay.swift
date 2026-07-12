import Foundation
import SwiftData

@Model
final class IntakeDay {
    /// Day-normalized date (start of day).
    var date: Date
    var proteinGrams: Int
    var waterMl: Int

    init(date: Date, proteinGrams: Int = 0, waterMl: Int = 0) {
        self.date = date
        self.proteinGrams = proteinGrams
        self.waterMl = waterMl
    }
}
