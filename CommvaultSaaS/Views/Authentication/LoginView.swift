import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var accessToken = ""
    @State private var refreshToken = ""
    @State private var showTokenInfo = false

    var body: some View {
        ZStack {
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

                        Text("User Dashboard")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.bottom, 20)

                    // Token Setup Card
                    VStack(spacing: 20) {
                        HStack {
                            Text("Connect to your environment")
                                .font(.headline)
                            Spacer()
                            Button {
                                showTokenInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.body)
                            }
                        }

                        // Access Token
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Access Token", systemImage: "key")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            SecureField("Paste your access token", text: $accessToken)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Refresh Token
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Refresh Token", systemImage: "arrow.clockwise")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            SecureField("Paste your refresh token", text: $refreshToken)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
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

                        // Connect Button
                        Button {
                            Task {
                                await authManager.setupTokens(
                                    accessToken: accessToken,
                                    refreshToken: refreshToken
                                )
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
                            Text("Tokens stored securely in iOS Keychain")
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
        .sheet(isPresented: $showTokenInfo) {
            TokenInfoSheet()
        }
    }

    private var isFormValid: Bool {
        !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !refreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct TokenInfoSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How to get your tokens")
                        .font(.title2)
                        .fontWeight(.bold)

                    VStack(alignment: .leading, spacing: 12) {
                        InfoStep(number: 1, text: "Log into your Commvault Command Center")
                        InfoStep(number: 2, text: "Go to Manage > Security > Access Tokens")
                        InfoStep(number: 3, text: "Click 'Add Token' to create a new access token")
                        InfoStep(number: 4, text: "Set the scope to 'All' for full API access")
                        InfoStep(number: 5, text: "Copy both the Access Token and Refresh Token")
                        InfoStep(number: 6, text: "Paste them into this app")
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Access tokens expire after 2 hours. The app will automatically renew them using the refresh token.")
                            .font(.caption)
                    }
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
            }
            .navigationTitle("Token Setup")
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
