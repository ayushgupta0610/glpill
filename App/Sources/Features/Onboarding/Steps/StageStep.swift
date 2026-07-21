import SwiftUI

struct StageStep: View {
    @Bindable var store: OnboardingStore
    let next: () -> Void
    private let options: [(id: String, label: String)] = [
        ("aboutToStart", "I'm about to start"),
        ("firstWeeks", "I'm in my first few weeks"),
        ("aWhile", "I've been on it a while"),
        ("switchingFromInjections", "I'm switching from injections"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Where are you in your pill journey?").font(.title.bold()).padding(.top, 24)
            Text("So we set the right expectations from day one.").font(.subheadline).foregroundStyle(.secondary)
            ForEach(options, id: \.id) { opt in
                OnboardingOptionRow(title: opt.label, subtitle: nil, selected: store.stage == opt.id, multi: false) {
                    store.stage = opt.id
                }
            }
            Spacer()
            PillCTAButton(title: "Continue", systemImage: "arrow.right") { next() }.padding(.bottom, 24)
        }
        .padding(.horizontal).background(Color(.systemGroupedBackground))
    }
}
