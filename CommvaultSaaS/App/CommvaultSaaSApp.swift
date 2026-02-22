import SwiftUI

@main
struct CommvaultSaaSApp: App {
    @StateObject private var authManager = AuthenticationManager()

    init() {
        configureAppAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
        }
    }

    private func configureAppAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(CommvaultColors.deepPurple)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        // Apply the same appearance to all three display modes so the back
        // chevron is always the same light tint regardless of scroll position
        // or whether we're inside a sheet's own NavigationStack.
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(white: 1.0, alpha: 0.75)
    }
}
