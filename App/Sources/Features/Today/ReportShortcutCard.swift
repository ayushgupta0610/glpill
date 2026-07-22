import SwiftUI

struct ReportShortcutCard: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button { router.selection = .report } label: {
            Card {
                HStack {
                    SectionHeader(title: "Doctor-ready report")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
                Text("Adherence, doses & side effects")
                    .font(.subheadline.weight(.medium))
            }
        }
        .buttonStyle(.plain)
    }
}
