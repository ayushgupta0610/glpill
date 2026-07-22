import SwiftUI

struct ReminderStyleStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    private let options: [(id: String, label: String)] = [
        ("full", "Pill time + when my window clears"),
        ("pillOnly", "Just the pill reminder"),
        ("none", "No reminders"),
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Never mistime a dose").font(.title.bold()).padding(.top, 24)
                Text("We'll only nudge you the way you choose.").font(.subheadline).foregroundStyle(.secondary)
                ForEach(options, id: \.id) { opt in
                    OnboardingOptionRow(title: opt.label, subtitle: nil, selected: store.reminderStyle == opt.id, multi: false) {
                        store.reminderStyle = opt.id
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
