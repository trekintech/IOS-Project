import SwiftUI
import Combine

struct InfrastructureHealthView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var viewModel = InfrastructureViewModel()
    @State private var selectedTab: InfraTab = .infrastructure

    enum InfraTab: String, CaseIterable {
        case infrastructure = "Infrastructure"
        case nonInfrastructure = "Non-Infrastructure"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Server Type", selection: $selectedTab) {
                ForEach(InfraTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading servers...")
                Spacer()
            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await viewModel.loadServers(authManager: authManager)
                        }
                    }
                }
                .padding()
                Spacer()
            } else {
                let servers = selectedTab == .infrastructure
                    ? viewModel.infrastructureServers
                    : viewModel.nonInfrastructureServers

                ScrollView {
                    VStack(spacing: 16) {
                        // Total count header
                        HStack {
                            Text("\(servers.count) servers")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)

                        // Status cards
                        ForEach(statusGroups(for: servers), id: \.status) { group in
                            NavigationLink {
                                ServerListView(
                                    title: group.status.rawValue,
                                    servers: group.servers,
                                    healthStatus: group.status
                                )
                            } label: {
                                HealthStatCard(
                                    status: group.status,
                                    count: group.servers.count,
                                    total: servers.count
                                )
                            }
                        }

                        if servers.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "server.rack")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("No servers found")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Infrastructure Health")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await authManager.renewIfNeeded()
            await viewModel.loadServers(authManager: authManager)
        }
        .task {
            await authManager.renewIfNeeded()
            await viewModel.loadServers(authManager: authManager)
        }
    }

    private func statusGroups(for servers: [CommvaultServer]) -> [ServerStatusGroup] {
        let grouped = Dictionary(grouping: servers) { $0.healthStatus }
        return grouped.map { ServerStatusGroup(status: $0.key, servers: $0.value) }
            .sorted { $0.status.sortOrder < $1.status.sortOrder }
    }
}

struct ServerStatusGroup {
    let status: ServerHealthStatus
    let servers: [CommvaultServer]
}

// MARK: - View Model

@MainActor
final class InfrastructureViewModel: ObservableObject {
    @Published var allServers: [CommvaultServer] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = CommvaultAPIService.shared

    /// Servers filtered to exclude NOT_APPLICABLE status
    private var applicableServers: [CommvaultServer] {
        allServers.filter { $0.isApplicable }
    }

    var infrastructureServers: [CommvaultServer] {
        applicableServers.filter { $0.isInfrastructure == true }
    }

    var nonInfrastructureServers: [CommvaultServer] {
        applicableServers.filter { $0.isInfrastructure != true }
    }

    func loadServers(authManager: AuthenticationManager) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await api.getServers()
            self.allServers = response.servers ?? []
        } catch CommvaultAPIError.unauthorized {
            let renewed = await authManager.handleUnauthorized()
            if renewed {
                do {
                    let response = try await api.getServers()
                    self.allServers = response.servers ?? []
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            } else {
                self.errorMessage = "Session expired. Please log out and re-authenticate."
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Health Stat Card

struct HealthStatCard: View {
    let status: ServerHealthStatus
    let count: Int
    let total: Int

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total) * 100
    }

    private var gradient: LinearGradient {
        switch status {
        case .offline:
            return LinearGradient(
                colors: [Color(hex: "7B1E1E"), Color(hex: "C93030")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .needsUpdate:
            return LinearGradient(
                colors: [Color(hex: "5C4B1E"), Color(hex: "B8860B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .healthy:
            return LinearGradient(
                colors: [Color(hex: "1E5C2E"), Color(hex: "2D8B4E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .unknown:
            return LinearGradient(
                colors: [Color(hex: "3A3A3C"), Color(hex: "636366")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: status.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(status.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Text(String(format: "%.0f%% of servers", percentage))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

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
        .shadow(color: status.color.opacity(0.3), radius: 10, y: 5)
    }
}
