import SwiftUI

struct ShareCardView: View {
    let streak: Int
    let changeText: String
    let weeks: Int

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "pills.fill")
                Text("GLPill")
                    .font(.headline.bold())
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Text(changeText)
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text("in \(weeks) week\(weeks == 1 ? "" : "s")")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            HStack {
                Label("\(streak)-day streak", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.2), in: Capsule())
                Spacer()
                Text("my GLP-1 journey")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(28)
        .frame(width: 360, height: 450)
        .background(Theme.heroGradient)
    }
}
