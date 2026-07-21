import SwiftUI

struct GoalsStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    private let options: [(id: String, label: String)] = [
        ("pillDaily", "Take my pill correctly every day"),
        ("consistency", "Build a streak & stay consistent"),
        ("sideEffects", "Manage side effects"),
        ("doctor", "Keep records for my doctor"),
        ("weight", "See my weight trend"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What should this app help with?").font(.title.bold()).padding(.top, 24)
            Text("We'll put what matters to you up front.").font(.subheadline).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(options, id: \.id) { opt in
                        OnboardingOptionRow(title: opt.label, subtitle: nil, selected: store.goals.contains(opt.id), multi: true) {
                            toggle(opt.id)
                        }
                    }
                }
            }
            PillCTAButton(title: "Continue", systemImage: "arrow.right") { next() }.padding(.bottom, 24)
        }
        .padding(.horizontal).background(Color(.systemGroupedBackground))
    }
    private func toggle(_ id: String) {
        if store.goals.contains(id) { store.goals.removeAll { $0 == id } } else { store.goals.append(id) }
    }
}
