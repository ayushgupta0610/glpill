import Foundation

struct ActivityEvent: Identifiable {
    enum Kind {
        case weighIn(kg: Double)
        case dose
        case milestone(JourneyMilestone)
    }

    let id: String
    let date: Date
    let kind: Kind
}

enum ActivityFeed {
    /// Merges weigh-ins, doses, and reached milestones into one
    /// reverse-chronological feed. Unreached milestones (`reachedDate ==
    /// nil`) are excluded — they haven't happened yet, so they're not an
    /// activity event.
    static func merge(
        weightEntries: [(id: String, date: Date, kg: Double)],
        doseLogs: [(id: String, date: Date)],
        milestones: [JourneyMilestone]
    ) -> [ActivityEvent] {
        var events: [ActivityEvent] = []
        events += weightEntries.map { ActivityEvent(id: "weight-\($0.id)", date: $0.date, kind: .weighIn(kg: $0.kg)) }
        events += doseLogs.map { ActivityEvent(id: "dose-\($0.id)", date: $0.date, kind: .dose) }
        events += milestones.compactMap { milestone in
            guard let reachedDate = milestone.reachedDate else { return nil }
            return ActivityEvent(id: "milestone-\(milestone.id)", date: reachedDate, kind: .milestone(milestone))
        }
        return events.sorted { $0.date > $1.date }
    }
}
