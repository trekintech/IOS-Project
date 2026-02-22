import SwiftUI

struct ServerListView: View {
    let title: String
    let servers: [CommvaultServer]
    let healthStatus: ServerHealthStatus

    @State private var searchText = ""

    private var filteredServers: [CommvaultServer] {
        if searchText.isEmpty {
            return servers
        }
        return servers.filter {
            $0.serverDisplayName.localizedCaseInsensitiveContains(searchText) ||
            ($0.hostName ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.version ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filteredServers) { server in
            ServerRow(server: server, healthStatus: healthStatus)
        }
        .searchable(text: $searchText, prompt: "Search servers")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Server Row

struct ServerRow: View {
    let server: CommvaultServer
    let healthStatus: ServerHealthStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Server name + status dot
            HStack(spacing: 8) {
                Circle()
                    .fill(healthStatus.color)
                    .frame(width: 10, height: 10)

                Text(server.serverDisplayName)
                    .font(.body)
                    .fontWeight(.medium)

                Spacer()

                if let version = server.version, !version.isEmpty {
                    Text("v\(version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospaced()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }

            // Details grid
            VStack(alignment: .leading, spacing: 4) {
                if let installDate = server.installDate {
                    DetailRow(
                        icon: "calendar",
                        label: "Installed",
                        value: installDate.formatted(.dateTime.month().day().year())
                    )
                }

                DetailRow(
                    icon: "person.badge.key",
                    label: "Roles",
                    value: server.rolesDisplay
                )

                if let os = server.additionalProperties?.osInfo, !os.isEmpty {
                    DetailRow(
                        icon: "desktopcomputer",
                        label: "OS",
                        value: os
                    )
                }

                // Show lastOnlineTime for offline servers
                if healthStatus == .offline, let lastOnline = server.lastOnlineDate {
                    DetailRow(
                        icon: "clock.badge.exclamationmark",
                        label: "Last Online",
                        value: lastOnline.formatted(.dateTime.month().day().year().hour().minute())
                    )
                }

                // Show lastOfflineTime for offline servers
                if healthStatus == .offline, let lastOffline = server.lastOfflineDate {
                    DetailRow(
                        icon: "wifi.slash",
                        label: "Went Offline",
                        value: lastOffline.formatted(.dateTime.month().day().year().hour().minute())
                    )
                }

                if server.needsUpdate {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("Update available")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 14)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
