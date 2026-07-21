import SwiftUI

struct ConcernsStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    private let options: [(id: String, label: String)] = [
        ("nausea", "Nausea"), ("constipation", "Constipation"),
        ("lowAppetite", "Low appetite / food noise"), ("fatigue", "Fatigue"),
        ("reflux", "Reflux / burping"), ("none", "Nothing yet"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What are you most worried about?").font(.title.bold()).padding(.top, 24)
            Text("We'll tailor gentle tips and make these one-tap to log.").font(.subheadline).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(options, id: \.id) { opt in
                        OnboardingOptionRow(title: opt.label, subtitle: nil, selected: store.concerns.contains(opt.id), multi: true) {
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
        if store.concerns.contains(id) { store.concerns.removeAll { $0 == id } } else { store.concerns.append(id) }
    }
}
