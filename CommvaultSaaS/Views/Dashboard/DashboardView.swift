import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 4) {
                        Text("m036.metallic.io")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .monospaced()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(viewModel.isLoading ? .orange : .green)
                                .frame(width: 8, height: 8)
                            Text(viewModel.isLoading ? "Loading..." : "Connected")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(CommvaultColors.cardGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if !viewModel.isLoading {
                        // Total Users Card
                        NavigationLink {
                            UserListView(
                                title: "All Users",
                                users: viewModel.allUsers
                            )
                        } label: {
                            StatCard(
                                icon: "person.3.fill",
                                title: "Total Users",
                                count: viewModel.totalUsers,
                                color: CommvaultColors.mediumPurple,
                                gradient: LinearGradient(
                                    colors: [CommvaultColors.deepPurple, CommvaultColors.navyBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        }

                        // Inactive 1+ Year Card
                        NavigationLink {
                            UserListView(
                                title: "Inactive 1+ Year",
                                users: viewModel.inactiveOneYearUsers
                            )
                        } label: {
                            StatCard(
                                icon: "clock.badge.exclamationmark",
                                title: "Inactive 1+ Year",
                                count: viewModel.inactiveOneYearCount,
                                subtitle: "Last login over 12 months ago",
                                color: CommvaultColors.warning,
                                gradient: LinearGradient(
                                    colors: [Color(hex: "7B4B1E"), Color(hex: "C97A1E")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        }

                        // Never Logged In Card
                        NavigationLink {
                            UserListView(
                                title: "Never Logged In",
                                users: viewModel.neverLoggedInUsers
                            )
                        } label: {
                            StatCard(
                                icon: "person.fill.xmark",
                                title: "Never Logged In",
                                count: viewModel.neverLoggedInCount,
                                subtitle: "No login activity recorded",
                                color: CommvaultColors.critical,
                                gradient: LinearGradient(
                                    colors: [Color(hex: "7B1E1E"), Color(hex: "C93030")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("User Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        authManager.logout()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await authManager.renewIfNeeded()
                            await viewModel.loadUsers()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await authManager.renewIfNeeded()
                await viewModel.loadUsers()
            }
            .task {
                await authManager.renewIfNeeded()
                await viewModel.loadUsers()
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var allUsers: [CommvaultUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = CommvaultAPIService.shared

    var totalUsers: Int { allUsers.count }

    var inactiveOneYearUsers: [CommvaultUser] {
        allUsers.filter { $0.isInactiveOneYear }
    }
    var inactiveOneYearCount: Int { inactiveOneYearUsers.count }

    var neverLoggedInUsers: [CommvaultUser] {
        allUsers.filter { $0.hasNeverLoggedIn }
    }
    var neverLoggedInCount: Int { neverLoggedInUsers.count }

    func loadUsers() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await api.getUsers()
            self.allUsers = response.users ?? []
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let title: String
    let count: Int
    var subtitle: String? = nil
    let color: Color
    let gradient: LinearGradient

    var body: some View {
        HStack(spacing: 16) {
            // Icon circle
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
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            // Count
            Text("\(count)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(20)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: color.opacity(0.3), radius: 10, y: 5)
    }
}

// MARK: - User List View

struct UserListView: View {
    let title: String
    let users: [CommvaultUser]

    @State private var searchText = ""

    private var filteredUsers: [CommvaultUser] {
        if searchText.isEmpty {
            return users
        }
        return users.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            ($0.email ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filteredUsers) { user in
            HStack(spacing: 12) {
                // Avatar circle with initials
                ZStack {
                    Circle()
                        .fill(CommvaultColors.mediumPurple.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Text(initials(for: user.displayName))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(CommvaultColors.mediumPurple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.body)
                        .fontWeight(.medium)

                    if let email = user.email, !email.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let date = user.lastLoginDate {
                        Text("Last login: \(date, format: .dateTime.month().day().year())")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Never logged in")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }

                Spacer()

                if user.enabled == true {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(.gray)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 4)
        }
        .searchable(text: $searchText, prompt: "Search users")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
