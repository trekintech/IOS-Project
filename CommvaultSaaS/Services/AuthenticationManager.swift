import Foundation
import Combine
import SwiftUI

/// Manages authentication state, secure API token storage, and ring configuration.
@MainActor
final class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var commCellDetails: CommCellDetails?
    @Published var ringIdentifier: String = ""

    private let keychain = KeychainManager.shared
    private let api = CommvaultAPIService.shared

    init() {
        restoreSession()
    }

    /// Restore a previous session from Keychain.
    /// If the token is expired, attempt renewal with the stored refresh token.
    private func restoreSession() {
        guard let token = keychain.retrieve(for: .apiToken),
              let ring = keychain.retrieve(for: .ringEndpoint) else {
            return
        }
        ringIdentifier = ring
        Task {
            await api.configure(ring: ring, token: token)
            do {
                let details = try await api.validateToken()
                self.commCellDetails = details
                self.isAuthenticated = true
            } catch CommvaultAPIError.unauthorized {
                // Token expired - try refreshing
                if await refreshTokenIfPossible() {
                    do {
                        let details = try await api.validateToken()
                        self.commCellDetails = details
                        self.isAuthenticated = true
                    } catch {
                        self.isAuthenticated = false
                    }
                } else {
                    self.isAuthenticated = false
                }
            } catch {
                self.isAuthenticated = false
            }
        }
    }

    /// Attempt to renew the access token using the stored refresh token.
    /// Returns true if renewal succeeded.
    func refreshTokenIfPossible() async -> Bool {
        guard let currentToken = keychain.retrieve(for: .apiToken),
              let refreshToken = keychain.retrieve(for: .refreshToken) else {
            return false
        }

        do {
            let response = try await api.renewAccessToken(
                accessToken: currentToken,
                refreshToken: refreshToken
            )
            guard let newAccess = response.accessToken,
                  let newRefresh = response.refreshToken else {
                return false
            }
            await api.updateToken(newAccess)
            try keychain.save(newAccess, for: .apiToken)
            try keychain.save(newRefresh, for: .refreshToken)
            return true
        } catch {
            return false
        }
    }

    /// Authenticate with an API key (recommended for SaaS)
    func loginWithAPIKey(ring: String, apiKey: String) async {
        isLoading = true
        errorMessage = nil

        let normalizedRing = normalizeRing(ring)
        guard isValidRing(normalizedRing) else {
            errorMessage = "Invalid ring format. Expected format: M## (e.g., M88, M123)"
            isLoading = false
            return
        }

        await api.configure(ring: normalizedRing, token: apiKey)

        do {
            let details = try await api.validateToken()
            try keychain.save(apiKey, for: .apiToken)
            try keychain.save(normalizedRing, for: .ringEndpoint)
            self.commCellDetails = details
            self.ringIdentifier = normalizedRing
            self.isAuthenticated = true
        } catch {
            errorMessage = "Authentication failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Authenticate with username/password
    func loginWithCredentials(ring: String, username: String, password: String) async {
        isLoading = true
        errorMessage = nil

        let normalizedRing = normalizeRing(ring)
        guard isValidRing(normalizedRing) else {
            errorMessage = "Invalid ring format. Expected format: M## (e.g., M88, M123)"
            isLoading = false
            return
        }

        do {
            let response = try await api.login(ring: normalizedRing, username: username, password: password)

            // Check for API-level errors first
            if let firstError = response.errList?.first,
               let code = firstError.errorCode, code != 0 {
                errorMessage = firstError.errorMessage ?? "Login failed (error \(code))."
                isLoading = false
                return
            }

            guard let token = response.effectiveToken else {
                errorMessage = "Login failed. No token received."
                isLoading = false
                return
            }

            if response.forcePasswordChange == true {
                errorMessage = "Your password must be changed. Please update it in the Command Center first."
                isLoading = false
                return
            }

            if response.isAccountLocked == true {
                errorMessage = "This account is locked. Contact your administrator."
                isLoading = false
                return
            }

            await api.configure(ring: normalizedRing, token: token)
            try keychain.save(token, for: .apiToken)
            try keychain.save(normalizedRing, for: .ringEndpoint)
            try keychain.save(username, for: .username)
            self.ringIdentifier = normalizedRing
            self.isAuthenticated = true
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func logout() {
        keychain.deleteAll()
        isAuthenticated = false
        commCellDetails = nil
        ringIdentifier = ""
        errorMessage = nil
    }

    /// Validate ring format: M followed by 2-3 digits
    func isValidRing(_ ring: String) -> Bool {
        let pattern = #"^[Mm]\d{2,3}$"#
        return ring.range(of: pattern, options: .regularExpression) != nil
    }

    /// Normalize ring input to uppercase
    private func normalizeRing(_ ring: String) -> String {
        let trimmed = ring.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.uppercased()
    }
}
