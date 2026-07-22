import SwiftUI

/// A realistic drinking glass that fills with water to `fraction` (0...1), with
/// the current amount shown large inside it. Animates the fill on change.
struct WaterGlassView: View {
    let fraction: Double
    let label: String

    private static let water = Color(uiColor: .systemBlue)

    var body: some View {
        let f = min(max(fraction, 0), 1)
        GeometryReader { geo in
            ZStack {
                // Empty glass interior.
                GlassShape().fill(Color(.tertiarySystemFill).opacity(0.35))

                // Water fill, clipped to the glass so it looks poured in.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ZStack(alignment: .top) {
                        LinearGradient(
                            colors: [Self.water.opacity(0.85), Self.water],
                            startPoint: .top, endPoint: .bottom
                        )
                        // Meniscus — a lighter ellipse at the surface for a real waterline.
                        Ellipse()
                            .fill(Self.water.opacity(0.45))
                            .frame(height: 9)
                            .offset(y: -4)
                    }
                    .frame(height: geo.size.height * f)
                }
                .clipShape(GlassShape())
                .animation(.spring(response: 0.45, dampingFraction: 0.72), value: f)

                // Glass outline on top.
                GlassShape().stroke(Self.water.opacity(0.55), lineWidth: 3)

                // Amount, centered inside the glass.
                Text(label)
                    .font(.title3.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .shadow(color: .white.opacity(0.4), radius: 1)
            }
        }
        .frame(width: 84, height: 104)
        .accessibilityHidden(true)
    }
}

/// A gently tapered drinking glass: open top, slightly narrower base, rounded bottom.
private struct GlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        let topInset = rect.width * 0.05
        let bottomInset = rect.width * 0.15
        let r = min(rect.width, rect.height) * 0.14
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - bottomInset, y: rect.maxY - r))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomInset - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX - bottomInset, y: rect.maxY)
        )
        p.addLine(to: CGPoint(x: rect.minX + bottomInset + r, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + bottomInset, y: rect.maxY - r),
            control: CGPoint(x: rect.minX + bottomInset, y: rect.maxY)
        )
        p.closeSubpath()
        return p
    }
}
