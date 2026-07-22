import SwiftUI

struct ReportShortcutCard: View {
    var body: some View {
        NavigationLink { ReportScreen() } label: {
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
