import SwiftUI

/// Drives the selected tab so in-app shortcuts can switch tabs instead of
/// pushing self-stacked screens (which would nest NavigationStacks).
@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case today, progress, history, report, settings
    }

    var selection: Tab = .today
}
