import Foundation

/// Stripped-back API service for Commvault Cloud user management.
/// All calls go directly to the ring: https://m036.metallic.io/commandcenter/api
/// Auth: `Authtoken: {accessToken}`
actor CommvaultAPIService {
    static let shared = CommvaultAPIService()

    private static let baseURL = "https://m036.metallic.io/commandcenter/api"

    private var authToken: String = ""
    private var lastCallTime: Date?

    // MARK: - Configuration

    func configure(token: String) {
        self.authToken = token
        self.lastCallTime = Date()
    }

    func updateToken(_ token: String) {
        self.authToken = token
        self.lastCallTime = Date()
    }

    /// Whether the token likely needs renewal (> 2 hours since last call).
    var needsTokenRenewal: Bool {
        guard let last = lastCallTime else { return true }
        return Date().timeIntervalSince(last) > 2 * 60 * 60
    }

    // MARK: - Users

    func getUsers(limit: Int = 1000) async throws -> UsersResponse {
        return try await get(endpoint: "/v4/user?limit=\(limit)")
    }

    // MARK: - Token Renewal

    func renewAccessToken(accessToken: String, refreshToken: String) async throws -> TokenRenewResponse {
        let url = Self.baseURL + "/V4/AccessToken/Renew"
        guard let requestURL = URL(string: url) else {
            throw CommvaultAPIError.invalidURL(url)
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(accessToken, forHTTPHeaderField: "Authtoken")

        let body = TokenRenewRequest(accessToken: accessToken, refreshToken: refreshToken)
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(TokenRenewResponse.self, from: data)
    }

    // MARK: - Network Layer

    private func get<T: Decodable>(endpoint: String) async throws -> T {
        let urlString = Self.baseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw CommvaultAPIError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(authToken, forHTTPHeaderField: "Authtoken")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        lastCallTime = Date()

        // Debug: dump raw JSON so we can verify field names
        if let raw = String(data: data, encoding: .utf8) {
            print("[API DEBUG] Raw response for \(endpoint):\n\(raw)")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CommvaultAPIError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw CommvaultAPIError.unauthorized
        case 403:
            throw CommvaultAPIError.forbidden
        case 404:
            throw CommvaultAPIError.notFound
        case 429:
            throw CommvaultAPIError.rateLimited
        case 500...599:
            throw CommvaultAPIError.serverError(httpResponse.statusCode)
        default:
            throw CommvaultAPIError.httpError(httpResponse.statusCode)
        }
    }
}

// MARK: - API Errors

enum CommvaultAPIError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response from server."
        case .unauthorized:
            return "Authentication failed. Token may have expired."
        case .forbidden:
            return "Access denied. Insufficient permissions."
        case .notFound:
            return "Resource not found."
        case .rateLimited:
            return "Rate limited. Please try again shortly."
        case .serverError(let code):
            return "Server error (\(code)). Please try again."
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let detail):
            return "Failed to parse response: \(detail)"
        }
    }
}
