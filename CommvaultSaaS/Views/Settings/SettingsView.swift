import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isRenewing = false
    @State private var showUpdateTokens = false
    @State private var showResetConfirm = false

    var body: some View {
        List {
            // MARK: - Connection
            Section {
                HStack {
                    Label("Ring", systemImage: "server.rack")
                    Spacer()
                    Text(authManager.ringHost)
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
                    Text("On launch & every 2 hrs")
                        .foregroundStyle(.secondary)
                        .font(.caption)
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

                Button {
                    showUpdateTokens = true
                } label: {
                    Label("Update Tokens", systemImage: "key.horizontal")
                }
            } header: {
                Text("Token")
            } footer: {
                Text("Tokens are automatically renewed on app launch and every 2 hours. When renewed, both the access token and refresh token are replaced and stored in the iOS Keychain.")
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

            // MARK: - Actions
            Section {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset Connection", systemImage: "arrow.counterclockwise")
                }

                Button(role: .destructive) {
                    authManager.logout()
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } footer: {
                Text("Reset clears all stored data and returns to the setup screen where you can enter a new ring and tokens. Log Out keeps your ring but clears tokens.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showUpdateTokens) {
            UpdateTokensSheet()
                .environmentObject(authManager)
        }
        .alert("Reset Connection?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                authManager.logout()
            }
        } message: {
            Text("This will clear your ring, tokens, and all stored data. You'll need to set up the connection again from scratch.")
        }
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

// MARK: - Update Tokens Sheet

struct UpdateTokensSheet: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    @State private var accessToken = ""
    @State private var refreshToken = ""

    private var isFormValid: Bool {
        !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !refreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Ring")
                        Spacer()
                        Text(authManager.ringHost)
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                } header: {
                    Text("Current Connection")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Access Token", systemImage: "key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("Paste new access token", text: $accessToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Refresh Token", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("Paste new refresh token", text: $refreshToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("New Tokens")
                } footer: {
                    Text("Enter new tokens to replace the current ones. The new tokens will be validated before saving.")
                }

                if let error = authManager.errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Button {
                        Task {
                            await authManager.updateTokens(
                                accessToken: accessToken,
                                refreshToken: refreshToken
                            )
                            if authManager.tokenStatus == .valid {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if authManager.isLoading {
                                ProgressView()
                            } else {
                                Text("Save & Validate")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || authManager.isLoading)
                }
            }
            .navigationTitle("Update Tokens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(Color(white: 1.0, opacity: 0.75))
    }
}
