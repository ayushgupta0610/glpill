import Foundation

enum ChartXDomain {
    /// Bounds the weight-trend chart's x-axis to the real weigh-in range plus a
    /// small pad, so a far-future projected-completion mark doesn't stretch the
    /// axis and compress the real entries into a sliver of the chart width.
    static func weightTrendDomain(firstEntryDate: Date, lastEntryDate: Date) -> ClosedRange<Date> {
        guard lastEntryDate >= firstEntryDate else { return firstEntryDate...firstEntryDate }
        let span = lastEntryDate.timeIntervalSince(firstEntryDate)
        let threeDays: TimeInterval = 60 * 60 * 24 * 3
        let padding = Swift.max(span * 0.15, threeDays)
        return firstEntryDate...lastEntryDate.addingTimeInterval(padding)
    }
}
