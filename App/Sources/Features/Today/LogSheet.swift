import SwiftUI

struct LogSheet: View {
    let onPill: () -> Void
    let onWeight: () -> Void
    let onWater: () -> Void
    let onProtein: () -> Void
    let onSideEffect: () -> Void

    var body: some View {
        NavigationStack {
            List {
                row("pills.fill", "Took my pill", onPill)
                row("scalemass.fill", "Weight", onWeight)
                row("drop.fill", "Water · +1 cup", onWater)
                row("fork.knife", "Protein · +25 g", onProtein)
                row("bandage.fill", "Side effects", onSideEffect)
            }
            .navigationTitle("Log for today")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private func row(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button { action() } label: { Label(title, systemImage: icon) }
    }
}
