import Foundation

/// Stripped-back API service for Commvault Cloud user management.
/// Ring-based URL: https://m{NNN}.metallic.io/commandcenter/api
/// Auth: `Authtoken: {accessToken}`
actor CommvaultAPIService {
    static let shared = CommvaultAPIService()

    private var ringNumber: String = "036"
    private var authToken: String = ""
    private var lastCallTime: Date?

    private var baseURL: String {
        "https://m\(ringNumber).metallic.io/commandcenter/api"
    }

    var currentRingHost: String {
        "m\(ringNumber).metallic.io"
    }

    // MARK: - Configuration

    func configure(token: String, ring: String) {
        self.authToken = token
        self.ringNumber = ring
        self.lastCallTime = Date()
    }

    func updateToken(_ token: String) {
        self.authToken = token
        self.lastCallTime = Date()
    }

    func updateRing(_ ring: String) {
        self.ringNumber = ring
    }

    /// Whether the token likely needs renewal (> 2 hours since last call).
    var needsTokenRenewal: Bool {
        guard let last = lastCallTime else { return true }
        return Date().timeIntervalSince(last) > 2 * 60 * 60
    }

    // MARK: - Users

    func getUsers() async throws -> UsersResponse {
        return try await get(endpoint: "/v4/user")
    }

    // MARK: - Servers

    func getServers() async throws -> ServersResponse {
        let endpoint = "/V4/Servers?fq=clientProperties.isServerClient%3Aeq%3Atrue&showOnlyInfrastructureMachines=0&additionalProperties=true&fl=clientProperties.client%2CclientProperties.clientProps%2CclientProperties.installDate%2Coverview"
        return try await getDebug(endpoint: endpoint)
    }

    /// Debug version of GET that prints raw JSON before decoding — temporary for response mapping.
    private func getDebug<T: Decodable>(endpoint: String) async throws -> T {
        let urlString = baseURL + endpoint
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

        // Debug: print raw JSON
        if let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let str = String(data: pretty, encoding: .utf8) {
            print("=== RAW /V4/Servers RESPONSE (first 3000 chars) ===")
            print(String(str.prefix(3000)))
            print("=== END RAW RESPONSE ===")
        }

        // Debug: print top-level keys
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("=== TOP-LEVEL KEYS: \(dict.keys.sorted()) ===")
            if let servers = dict["serversList"] as? [[String: Any]], let first = servers.first {
                print("=== FIRST SERVER (serversList) KEYS: \(first.keys.sorted()) ===")
            }
            if let servers = dict["servers"] as? [[String: Any]], let first = servers.first {
                print("=== FIRST SERVER (servers) KEYS: \(first.keys.sorted()) ===")
            }
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("=== DECODING ERROR: \(error) ===")
            throw error
        }
    }

    // MARK: - Token Renewal

    func renewAccessToken(accessToken: String, refreshToken: String) async throws -> TokenRenewResponse {
        let url = baseURL + "/V4/AccessToken/Renew"
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
        let urlString = baseURL + endpoint
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
