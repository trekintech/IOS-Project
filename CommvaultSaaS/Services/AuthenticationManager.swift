import Foundation
import Combine
import SwiftUI

/// Manages token storage, ring selection, and automatic renewal.
/// No username/password login — just access token + refresh token.
@MainActor
final class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRenewalDate: Date?
    @Published var tokenStatus: TokenStatus = .unknown
    @Published var ringNumber: String = ""

    enum TokenStatus: String {
        case unknown = "Unknown"
        case valid = "Valid"
        case renewed = "Renewed"
        case expired = "Expired"
        case failed = "Renewal Failed"
    }

    private let keychain = KeychainManager.shared
    private let api = CommvaultAPIService.shared

    var ringHost: String {
        ringNumber.isEmpty ? "Not configured" : "m\(ringNumber).metallic.io"
    }

    init() {
        restoreSession()
    }

    /// Restore session from Keychain, then immediately renew the token
    /// so the app never uses a potentially stale token.
    private func restoreSession() {
        guard let token = keychain.retrieve(for: .apiToken),
              let _ = keychain.retrieve(for: .refreshToken),
              let ring = keychain.retrieve(for: .ringEndpoint), !ring.isEmpty else {
            return
        }

        ringNumber = ring

        Task {
            await api.configure(token: token, ring: ring)
            self.isAuthenticated = true
            await renewToken()
        }
    }

    /// Store ring + tokens, validate by fetching users.
    func setupTokens(ring: String, accessToken: String, refreshToken: String) async {
        isLoading = true
        errorMessage = nil

        let trimmedRing = ring.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccess = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRefresh = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)

        await api.configure(token: trimmedAccess, ring: trimmedRing)

        do {
            let _ = try await api.getUsers()
            try keychain.save(trimmedRing, for: .ringEndpoint)
            try keychain.save(trimmedAccess, for: .apiToken)
            try keychain.save(trimmedRefresh, for: .refreshToken)
            self.ringNumber = trimmedRing
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

    /// Update tokens on an existing session (from Settings).
    func updateTokens(accessToken: String, refreshToken: String) async {
        isLoading = true
        errorMessage = nil

        let trimmedAccess = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRefresh = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)

        await api.updateToken(trimmedAccess)

        do {
            let _ = try await api.getUsers()
            try keychain.save(trimmedAccess, for: .apiToken)
            try keychain.save(trimmedRefresh, for: .refreshToken)
            self.tokenStatus = .valid
            self.lastRenewalDate = Date()
            self.errorMessage = nil
        } catch CommvaultAPIError.unauthorized {
            errorMessage = "Invalid access token."
            tokenStatus = .expired
        } catch {
            errorMessage = "Connection failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Force-renew the token and store the new pair in Keychain.
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
                tokenStatus = .valid
            }
        } catch {
            tokenStatus = .failed
        }
    }

    /// Renew only if it's been > 2 hours since the last call.
    func renewIfNeeded() async {
        let needsRenewal = await api.needsTokenRenewal
        guard needsRenewal else { return }
        await renewToken()
    }

    /// Called when a 401 is received. Attempts renewal, returns true if fresh token available.
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
        ringNumber = ""
    }
}
