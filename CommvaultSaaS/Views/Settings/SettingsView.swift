import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isRenewing = false

    var body: some View {
        List {
            // MARK: - Connection
            Section {
                HStack {
                    Label("Ring", systemImage: "server.rack")
                    Spacer()
                    Text("m036.metallic.io")
                        .foregroundStyle(.secondary)
                        .monospaced()
                }

                HStack {
                    Label("API Endpoint", systemImage: "link")
                    Spacer()
                    Text("/commandcenter/api")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .monospaced()
                }
            } header: {
                Text("Connection")
            }

            // MARK: - Token Status
            Section {
                HStack {
                    Label("Status", systemImage: tokenIcon)
                    Spacer()
                    Text(authManager.tokenStatus.rawValue)
                        .foregroundStyle(tokenColor)
                        .fontWeight(.medium)
                }

                if let date = authManager.lastRenewalDate {
                    HStack {
                        Label("Last Renewed", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text(date, format: .dateTime.month().day().year().hour().minute())
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }

                HStack {
                    Label("Auto-Renewal", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    Text("Every 2 hours")
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        isRenewing = true
                        await authManager.renewToken()
                        isRenewing = false
                    }
                } label: {
                    HStack {
                        Label("Renew Token Now", systemImage: "arrow.clockwise")
                        Spacer()
                        if isRenewing {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRenewing)
            } header: {
                Text("Token")
            } footer: {
                Text("Tokens are automatically renewed on app launch and every 2 hours. When renewed, both the access token and refresh token are replaced with fresh ones and stored in the iOS Keychain.")
            }

            // MARK: - Security
            Section {
                HStack {
                    Label("Storage", systemImage: "lock.shield")
                    Spacer()
                    Text("iOS Keychain")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Protection", systemImage: "lock.fill")
                    Spacer()
                    Text("Device-only, encrypted")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                HStack {
                    Label("TLS", systemImage: "checkmark.shield")
                    Spacer()
                    Text("1.2+ with forward secrecy")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } header: {
                Text("Security")
            }

            // MARK: - About
            Section {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text("1.0")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("About")
            }

            // MARK: - Logout
            Section {
                Button(role: .destructive) {
                    authManager.logout()
                } label: {
                    HStack {
                        Spacer()
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            } footer: {
                Text("Removes all stored tokens from the Keychain and returns to the login screen.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tokenIcon: String {
        switch authManager.tokenStatus {
        case .valid, .renewed: return "checkmark.circle.fill"
        case .expired: return "xmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private var tokenColor: Color {
        switch authManager.tokenStatus {
        case .valid, .renewed: return .green
        case .expired: return .red
        case .failed: return .orange
        case .unknown: return .secondary
        }
    }
}
