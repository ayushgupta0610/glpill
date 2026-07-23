import SwiftUI

/// A circular progress ring for protein: a tinted arc sweeping from the top by
/// `fraction` (0...1), a dot marking the current position, and the amount in the
/// center. Animates on change.
struct ProteinRingView: View {
    let fraction: Double
    let tint: Color
    let label: String

    private static let size: CGFloat = 100
    private static let lineWidth: CGFloat = 10
    /// Centerline radius of the stroked ring — used to place the marker dot.
    private static var radius: CGFloat { (size - lineWidth) / 2 }

    var body: some View {
        let f = min(max(fraction, 0), 1)
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: Self.lineWidth)

            Circle()
                .trim(from: 0, to: f)
                .stroke(tint, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.45, dampingFraction: 0.72), value: f)

            // Marker dot at the current position (12 o'clock at 0).
            Circle()
                .fill(tint)
                .frame(width: 14, height: 14)
                .offset(y: -Self.radius)
                .rotationEffect(.degrees(360 * f))
                .animation(.spring(response: 0.45, dampingFraction: 0.72), value: f)

            Text(label)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityHidden(true)
    }
}
