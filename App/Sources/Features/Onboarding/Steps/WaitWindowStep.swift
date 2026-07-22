import SwiftUI

struct WaitWindowStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    private let options: [(min: Int, label: String, note: String)] = [
        (30, "30 minutes", "the minimum"), (45, "45 minutes", ""),
        (60, "1 hour", ""), (120, "As long as I can", "up to 2h"),
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How long can you wait before breakfast?").font(.title.bold()).padding(.top, 24)
                Text("You must wait at least 30 minutes. Waiting longer absorbs more of the medicine — we'll time it for you.")
                    .font(.subheadline).foregroundStyle(.secondary)
                ForEach(options, id: \.min) { opt in
                    OnboardingOptionRow(title: opt.label, subtitle: opt.note.isEmpty ? nil : opt.note,
                                        selected: store.waitWindowMinutes == opt.min, multi: false) {
                        store.waitWindowMinutes = opt.min
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            PillCTAButton(title: "Continue", systemImage: "arrow.right") { next() }
                .padding(.horizontal).padding(.bottom, 24)
        }
    }
}
