import SwiftUI

/// A lightweight, dependency-free confetti burst: `count` small colored capsules
/// that fall and fade over ~1.5s. Per-particle variation is derived deterministically
/// from the particle index (no `Math.random`) so previews and tests stay stable.
struct ConfettiView: View {
    let count: Int
    let colors: [Color]

    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    particle(i, in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) { progress = 1 }
        }
    }

    private func particle(_ i: Int, in size: CGSize) -> some View {
        let startX = frac(Double(i) * 12.9898) * Double(size.width)
        let drift = (frac(Double(i) * 78.233) - 0.5) * 80
        let fallDistance = Double(size.height) * (0.6 + frac(Double(i) * 43.7585) * 0.5)
        let rotation = frac(Double(i) * 27.19) * 360
        let color = colors.isEmpty ? Color.accentColor : colors[i % colors.count]

        return Capsule()
            .fill(color)
            .frame(width: 6, height: 12)
            .rotationEffect(.degrees(rotation + Double(progress) * 180))
            .position(
                x: startX + Double(progress) * drift,
                y: -20 + Double(progress) * (fallDistance + 40)
            )
            .opacity(1 - Double(progress))
    }

    /// Deterministic fractional pseudo-variation from an index-derived value.
    private func frac(_ x: Double) -> Double {
        let s = sin(x) * 43758.5453
        return s - floor(s)
    }
}
