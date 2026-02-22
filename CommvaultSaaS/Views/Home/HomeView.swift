import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 4) {
                        Text(authManager.ringHost)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .monospaced()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Connected")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(CommvaultColors.cardGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Menu Cards
                    NavigationLink {
                        InfrastructureHealthView()
                            .environmentObject(authManager)
                    } label: {
                        HomeMenuCard(
                            icon: "server.rack",
                            title: "Infrastructure Health",
                            subtitle: "Server status, updates & connectivity",
                            gradient: LinearGradient(
                                colors: [CommvaultColors.deepPurple, CommvaultColors.navyBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }

                    NavigationLink {
                        DashboardView()
                            .environmentObject(authManager)
                    } label: {
                        HomeMenuCard(
                            icon: "person.3.fill",
                            title: "User Dashboard",
                            subtitle: "User activity, logins & account status",
                            gradient: LinearGradient(
                                colors: [CommvaultColors.purple, CommvaultColors.mediumPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("CV Cloud")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                            .environmentObject(authManager)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }
}

// MARK: - Home Menu Card

struct HomeMenuCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: LinearGradient

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(20)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
}
