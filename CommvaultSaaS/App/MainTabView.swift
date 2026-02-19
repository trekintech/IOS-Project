import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)

            JobsView()
                .tabItem {
                    Label("Jobs", systemImage: "list.bullet.clipboard.fill")
                }
                .tag(1)

            RAGChatView()
                .tabItem {
                    Label("Ask CV", systemImage: "bubble.left.and.text.bubble.right.fill")
                }
                .tag(2)

            CompetitiveView()
                .tabItem {
                    Label("Intel", systemImage: "binoculars.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(CommvaultColors.rosePink)
    }
}
