import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var ring = ""
    @State private var apiKey = ""
    @State private var showAPIKeyInfo = false
    @State private var useCredentials = false
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            // Background gradient
            CommvaultColors.heroGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)

                    // Logo / Title
                    VStack(spacing: 8) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 64))
                            .foregroundStyle(.white)

                        Text("Commvault Cloud")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("SaaS Dashboard")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.bottom, 20)

                    // Login Card
                    VStack(spacing: 20) {
                        // Ring Input
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Ring Endpoint", systemImage: "globe")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                TextField("M88", text: $ring)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .font(.body.monospaced())

                                Text(".metallic.io")
                                    .font(.body.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            if !ring.isEmpty && !authManager.isValidRing(ring.uppercased()) {
                                Text("Format: M followed by 2-3 digits (e.g., M88, M123)")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }

                        // Auth Method Toggle
                        Picker("Auth Method", selection: $useCredentials) {
                            Text("API Key").tag(false)
                            Text("Credentials").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if useCredentials {
                            // 2FA Warning
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundStyle(.orange)
                                Text("Commvault Cloud requires 2FA. If enabled, password login will not work — use an API Key instead.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Username / Password
                            VStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Username", systemImage: "person")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    TextField("admin@company.com", text: $username)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .keyboardType(.emailAddress)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Password", systemImage: "lock")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    SecureField("Password", text: $password)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        } else {
                            // API Key
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label("API Key", systemImage: "key")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Button {
                                        showAPIKeyInfo = true
                                    } label: {
                                        Image(systemName: "info.circle")
                                            .font(.caption)
                                    }
                                }

                                SecureField("Paste your API key", text: $apiKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // Error Message
                        if let error = authManager.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .padding(.horizontal)
                        }

                        // Login Button
                        Button {
                            Task {
                                if useCredentials {
                                    await authManager.loginWithCredentials(
                                        ring: ring,
                                        username: username,
                                        password: password
                                    )
                                } else {
                                    await authManager.loginWithAPIKey(
                                        ring: ring,
                                        apiKey: apiKey
                                    )
                                }
                            }
                        } label: {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Connect")
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                isFormValid
                                    ? CommvaultColors.mediumPurple
                                    : Color.gray
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!isFormValid || authManager.isLoading)

                        // Security Note
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                                .font(.caption2)
                            Text("API key stored securely in iOS Keychain")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 40)
                }
            }
        }
        .sheet(isPresented: $showAPIKeyInfo) {
            APIKeyInfoSheet()
        }
    }

    private var isFormValid: Bool {
        let ringValid = authManager.isValidRing(ring.uppercased())
        if useCredentials {
            return ringValid && !username.isEmpty && !password.isEmpty
        } else {
            return ringValid && !apiKey.isEmpty
        }
    }
}

struct APIKeyInfoSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How to get your API Key")
                        .font(.title2)
                        .fontWeight(.bold)

                    VStack(alignment: .leading, spacing: 12) {
                        InfoStep(number: 1, text: "Log into your Commvault Command Center")
                        InfoStep(number: 2, text: "Go to Manage > Security > Users")
                        InfoStep(number: 3, text: "Select the Access Tokens tab")
                        InfoStep(number: 4, text: "Click 'Add Token' to create a new access token")
                        InfoStep(number: 5, text: "Set the scope to 'All' for full API access")
                        InfoStep(number: 6, text: "Copy both the access token and the refresh token")
                        InfoStep(number: 7, text: "Paste the access token here as your API key")
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Access tokens expire after 30 minutes of inactivity but can be automatically renewed using the refresh token for up to 90 days.")
                            .font(.caption)
                    }
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Divider()

                    Text("Security Notes")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint(text: "Your API key is stored exclusively in the iOS Keychain with hardware-level encryption")
                        BulletPoint(text: "The key is only accessible when the device is unlocked")
                        BulletPoint(text: "The key never leaves your device - all API calls are made directly to your Commvault ring")
                        BulletPoint(text: "You can revoke the token at any time from the Command Center")
                    }
                }
                .padding()
            }
            .navigationTitle("API Key Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct InfoStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(CommvaultColors.mediumPurple)
                .clipShape(Circle())

            Text(text)
                .font(.body)
        }
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(CommvaultColors.success)
                .font(.caption)
            Text(text)
                .font(.callout)
        }
    }
}
