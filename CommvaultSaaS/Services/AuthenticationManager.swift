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
    @Published var lastRenewalDate: Date?
    @Published var tokenStatus: TokenStatus = .unknown

    enum TokenStatus: String {
        case unknown = "Unknown"
        case valid = "Valid"
        case renewed = "Renewed"
        case expired = "Expired"
        case failed = "Renewal Failed"
    }

    private let keychain = KeychainManager.shared
    private let api = CommvaultAPIService.shared

    init() {
        // Load last renewal date from stored value
        if let stored = keychain.retrieve(for: .apiToken), !stored.isEmpty {
            lastRenewalDate = nil // Will be set on first successful renewal
        }
        restoreSession()
    }

    /// Restore session from Keychain, then immediately renew the token
    /// so the app never uses a potentially stale token.
    private func restoreSession() {
        guard let token = keychain.retrieve(for: .apiToken),
              let _ = keychain.retrieve(for: .refreshToken) else {
            return
        }

        Task {
            await api.configure(token: token)
            self.isAuthenticated = true
            // Immediately renew on launch so the token is always fresh
            await renewToken()
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
            let _ = try await api.getUsers()
            try keychain.save(trimmedAccess, for: .apiToken)
            try keychain.save(trimmedRefresh, for: .refreshToken)
            self.isAuthenticated = true
            self.tokenStatus = .valid
            self.lastRenewalDate = Date()
        } catch CommvaultAPIError.unauthorized {
            errorMessage = "Invalid access token. Please check and try again."
            tokenStatus = .expired
        } catch CommvaultAPIError.forbidden {
            errorMessage = "Access denied. Ensure the token has sufficient permissions."
        } catch {
            errorMessage = "Connection failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Force-renew the token and store the new pair in Keychain.
    /// Called on app launch, before API calls, and from Settings.
    func renewToken() async {
        guard let currentToken = keychain.retrieve(for: .apiToken),
              let refreshToken = keychain.retrieve(for: .refreshToken) else {
            tokenStatus = .expired
            return
        }

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
                tokenStatus = .renewed
                lastRenewalDate = Date()
            } else {
                // API responded but no new tokens — current token may still work
                tokenStatus = .valid
            }
        } catch {
            // Renewal failed — token may still work, don't log out yet
            tokenStatus = .failed
        }
    }

    /// Renew only if it's been > 2 hours since the last call.
    /// For use before routine API calls.
    func renewIfNeeded() async {
        let needsRenewal = await api.needsTokenRenewal
        guard needsRenewal else { return }
        await renewToken()
    }

    /// Called by the API service when a 401 is received.
    /// Attempts to renew and returns true if a fresh token is now available.
    func handleUnauthorized() async -> Bool {
        await renewToken()
        return tokenStatus == .renewed
    }

    func logout() {
        keychain.deleteAll()
        isAuthenticated = false
        errorMessage = nil
        tokenStatus = .unknown
        lastRenewalDate = nil
    }
}
