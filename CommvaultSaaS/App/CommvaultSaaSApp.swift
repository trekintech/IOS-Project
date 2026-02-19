import SwiftUI

@main
struct CommvaultSaaSApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var settingsManager = SettingsManager()

    init() {
        configureAppAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(notificationManager)
                .environmentObject(settingsManager)
                .onAppear {
                    notificationManager.requestPermission()
                    if settingsManager.morningDigestEnabled {
                        notificationManager.scheduleMorningDigest()
                    }
                    if settingsManager.cohesityTrackingEnabled {
                        notificationManager.scheduleCohesityCheck()
                    }
                }
        }
    }

    private func configureAppAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(CommvaultColors.deepPurple)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = .white

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(CommvaultColors.deepPurple)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = UIColor(CommvaultColors.rosePink)
        UITabBar.appearance().unselectedItemTintColor = UIColor.white.withAlphaComponent(0.6)
    }
}
