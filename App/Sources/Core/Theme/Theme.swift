import SwiftUI

enum Theme {
    static let primary = Color(red: 0.055, green: 0.486, blue: 0.482)
    static let primaryDeep = Color(red: 0.031, green: 0.353, blue: 0.349)
    static let mint = Color(red: 0.42, green: 0.78, blue: 0.67)
    static let warn = Color(red: 0.94, green: 0.58, blue: 0.22)

    static let heroGradient = LinearGradient(
        colors: [primary, mint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardCornerRadius: CGFloat = 16
}
