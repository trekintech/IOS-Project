import Foundation
import Combine
import SwiftUI

/// Manages token storage and automatic renewal.
/// No username/password login — just access token + refresh token.
@MainActor
final class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let keychain = KeychainManager.shared
    private let api = CommvaultAPIService.shared

    init() {
        restoreSession()
    }

    /// Restore session from Keychain if tokens exist.
    private func restoreSession() {
        guard let token = keychain.retrieve(for: .apiToken),
              let _ = keychain.retrieve(for: .refreshToken) else {
            return
        }
        Task {
            await api.configure(token: token)
            self.isAuthenticated = true
        }
    }

    /// Store access token + refresh token, validate by fetching users.
    func setupTokens(accessToken: String, refreshToken: String) async {
        isLoading = true
        errorMessage = nil

        let trimmedAccess = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRefresh = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)

        await api.configure(token: trimmedAccess)

        do {
            let _ = try await api.getUsers(limit: 1)
            try keychain.save(trimmedAccess, for: .apiToken)
            try keychain.save(trimmedRefresh, for: .refreshToken)
            self.isAuthenticated = true
        } catch CommvaultAPIError.unauthorized {
            errorMessage = "Invalid access token. Please check and try again."
        } catch CommvaultAPIError.forbidden {
            errorMessage = "Access denied. Ensure the token has sufficient permissions."
        } catch {
            errorMessage = "Connection failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Renew access token using refresh token if > 2 hours since last call.
    func renewIfNeeded() async {
        guard let currentToken = keychain.retrieve(for: .apiToken),
              let refreshToken = keychain.retrieve(for: .refreshToken) else { return }

        let needsRenewal = await api.needsTokenRenewal
        guard needsRenewal else { return }

        do {
            let response = try await api.renewAccessToken(
                accessToken: currentToken,
                refreshToken: refreshToken
            )
            if let newAccess = response.accessToken,
               let newRefresh = response.refreshToken {
                await api.updateToken(newAccess)
                try keychain.save(newAccess, for: .apiToken)
                try keychain.save(newRefresh, for: .refreshToken)
            }
        } catch {
            // Renewal failed — existing token might still be valid
        }
    }

    func logout() {
        keychain.deleteAll()
        isAuthenticated = false
        errorMessage = nil
    }
}
