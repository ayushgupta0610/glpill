import SwiftUI

/// Neutral, source-cited explainer for the Rybelsus empty-stomach window.
/// Educational only — no advice, no per-drug interaction claims.
struct RitualExplainerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Why the 30-minute window?")
                        .font(.title2.bold())
                    Text("Oral semaglutide (Rybelsus®) is absorbed best on an empty stomach. The FDA label says to take it with a sip of plain water and then wait at least 30 minutes before eating, drinking anything else, or taking other oral medications.")
                        .font(.body)
                    Text("That's why GLPill starts a 30-minute countdown the moment you log your pill, and tells you when the window is clear — including when you can take your other morning meds.")
                        .font(.body)
                    Text("GLPill is a tracking tool, not medical advice. Always follow your prescriber's instructions and the timing your own doctor gives you.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Source: Rybelsus® Prescribing Information (FDA, via DailyMed).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
