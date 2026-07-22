import SwiftUI

struct MainTabView: View {
    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.selection) {
            TodayView()
                .tabItem { Label("Today", systemImage: "pills.fill") }
                .tag(AppRouter.Tab.today)
            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppRouter.Tab.progress)
            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }
                .tag(AppRouter.Tab.history)
            ReportScreen()
                .tabItem { Label("Report", systemImage: "doc.text") }
                .tag(AppRouter.Tab.report)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppRouter.Tab.settings)
        }
        .environment(router)
    }
}
