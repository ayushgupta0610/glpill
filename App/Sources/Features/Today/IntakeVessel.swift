import SwiftUI

/// A vessel that fills bottom-up to `fraction` (0...1). Glass for water, shaker for protein.
struct IntakeVessel: View {
    let fraction: Double
    let tint: Color
    var isShaker: Bool = false

    private var shape: some Shape { RoundedRectangle(cornerRadius: isShaker ? 8 : 12, style: .continuous) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                shape.fill(Color(.tertiarySystemFill))
                Rectangle()
                    .fill(tint)
                    .frame(height: geo.size.height * min(max(fraction, 0), 1))
                    .animation(.snappy, value: fraction)
            }
            .clipShape(shape)
            .overlay(shape.stroke(tint.opacity(0.55), lineWidth: 3))
            .overlay(alignment: .top) {
                if isShaker {
                    Capsule().fill(tint.opacity(0.55)).frame(height: 5).padding(.horizontal, 6).padding(.top, 3)
                }
            }
        }
        .frame(width: 54, height: 72)
        .accessibilityHidden(true)
    }
}
