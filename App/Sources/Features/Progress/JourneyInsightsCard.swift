import SwiftUI

/// Renders nothing when there are no insights — no empty-state placeholder,
/// per spec (a card with nothing to say shouldn't take up space).
struct JourneyInsightsCard: View {
    let insights: [JourneyInsight]

    var body: some View {
        if !insights.isEmpty {
            Card {
                SectionHeader(title: "Insights")
                ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                    Label(insight.text, systemImage: "sparkles")
                        .font(.subheadline)
                }
            }
        }
    }
}
