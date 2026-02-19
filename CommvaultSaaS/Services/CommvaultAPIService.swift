import Foundation

/// Core service for all Commvault REST API interactions.
/// Endpoints follow the pattern: https://{ring}.metallic.io/commandcenter/api/...
/// Ring format: M## or M### (e.g., M88, M123)
actor CommvaultAPIService {
    static let shared = CommvaultAPIService()

    private var baseURL: String = ""
    private var authToken: String = ""

    // MARK: - Configuration

    func configure(ring: String, token: String) {
        self.baseURL = "https://\(ring).metallic.io/commandcenter/api"
        self.authToken = token
    }

    func updateToken(_ token: String) {
        self.authToken = token
    }

    // MARK: - Authentication Operations

    /// Login and retrieve auth token. For SaaS, use API key as bearer token.
    func login(ring: String, username: String, password: String) async throws -> LoginResponse {
        let url = "https://\(ring).metallic.io/commandcenter/api/Login"
        let body: [String: Any] = [
            "username": username,
            "password": password,
        ]
        return try await post(url: url, body: body, authenticated: false)
    }

    /// Validate that an API token is working
    func validateToken() async throws -> CommCellDetails {
        return try await get(endpoint: "/CommServ/CommCellInfo")
    }

    /// Create a new access token
    func createAccessToken(tokenName: String, expiryDays: Int = 365) async throws -> [String: Any] {
        let body: [String: Any] = [
            "tokenName": tokenName,
            "tokenExpiry": [
                "days": expiryDays
            ],
            "tokenType": "ALL"
        ]
        let data = try await postRaw(endpoint: "/ApiToken", body: body)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CommvaultAPIError.invalidResponse
        }
        return json
    }

    /// List existing access tokens
    func listAccessTokens(userId: Int? = nil) async throws -> Data {
        var endpoint = "/ApiToken"
        if let userId = userId {
            endpoint += "?userId=\(userId)"
        }
        return try await getRaw(endpoint: endpoint)
    }

    // MARK: - Dashboard Operations

    /// Get CommCell details: name, version, release, ID
    func getCommCellDetails() async throws -> CommCellDetails {
        return try await get(endpoint: "/CommServ/CommCellInfo")
    }

    /// Get health overview for the environment
    func getHealthOverview(commUniId: Int = 10000) async throws -> HealthOverviewResponse {
        return try await get(endpoint: "/DashboardTile/HealthOverview?parameter.commUniId=\(commUniId)")
    }

    /// Get entity count (clients, agents, etc.)
    func getEntityCount() async throws -> EntityCountResponse {
        return try await get(endpoint: "/Client/Count")
    }

    /// Get SLA details
    func getSLADetails() async throws -> SLAResponse {
        return try await get(endpoint: "/DashboardTile/SLA")
    }

    /// Get storage space utilization
    func getStorageUtilization() async throws -> StorageUtilizationResponse {
        return try await get(endpoint: "/DashboardTile/StorageSpace")
    }

    /// Get anomalous entities
    func getAnomalousEntities() async throws -> AnomalousEntitiesResponse {
        return try await get(endpoint: "/DashboardTile/AnomalousEntities")
    }

    /// Get jobs summary for last 24 hours
    func getJobs24Hours() async throws -> Jobs24HResponse {
        return try await get(endpoint: "/DashboardTile/JobsInLast24Hours")
    }

    /// Get environment details
    func getEnvironmentDetails() async throws -> Data {
        return try await getRaw(endpoint: "/DashboardTile/EnvironmentDetails")
    }

    // MARK: - Job Operations

    /// Get list of jobs, with optional filters
    func getJobs(
        clientId: Int? = nil,
        jobFilter: JobFilter = .all,
        limit: Int = 50,
        lookupTime: Int = 86400  // last 24h in seconds
    ) async throws -> JobListResponse {
        var params = [
            "limit": "\(limit)",
            "lookupTime": "\(lookupTime)",
        ]
        if let clientId = clientId {
            params["clientId"] = "\(clientId)"
        }
        if jobFilter != .all {
            params["status"] = jobFilter.rawValue
        }
        let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        return try await get(endpoint: "/Job?\(queryString)")
    }

    /// Get detailed info for a specific job
    func getJobDetails(jobId: Int) async throws -> JobDetailsResponse {
        return try await get(endpoint: "/Job/\(jobId)")
    }

    /// Get job summary
    func getJobSummary(jobId: Int) async throws -> Data {
        return try await getRaw(endpoint: "/Job/\(jobId)/Summary")
    }

    /// Get failed items for a job
    func getFailedItems(jobId: Int) async throws -> Data {
        return try await getRaw(endpoint: "/Job/\(jobId)/FailedItems")
    }

    /// Resubmit a failed job
    func resubmitJob(jobId: Int) async throws -> Data {
        return try await postRaw(endpoint: "/Job/\(jobId)/Action/Resubmit", body: [:])
    }

    /// Kill a running job
    func killJob(jobId: Int) async throws -> Data {
        return try await postRaw(endpoint: "/Job/\(jobId)/Action/Kill", body: [:])
    }

    /// Suspend a job
    func suspendJob(jobId: Int) async throws -> Data {
        return try await postRaw(endpoint: "/Job/\(jobId)/Action/Suspend", body: [:])
    }

    /// Resume a job
    func resumeJob(jobId: Int) async throws -> Data {
        return try await postRaw(endpoint: "/Job/\(jobId)/Action/Resume", body: [:])
    }

    // MARK: - Monitoring / Alerts

    /// Get triggered alerts
    func getAlerts(pageSize: Int = 50, pageNo: Int = 1) async throws -> AlertsResponse {
        return try await get(endpoint: "/AlertRule/Triggered?pageSize=\(pageSize)&pageNo=\(pageNo)")
    }

    /// Get alert definitions
    func getAlertDefinitions() async throws -> Data {
        return try await getRaw(endpoint: "/AlertRule")
    }

    /// Mark alert as read
    func markAlertRead(alertId: Int) async throws -> Data {
        return try await postRaw(endpoint: "/AlertRule/Triggered/\(alertId)/Read", body: [:])
    }

    // MARK: - Usage / Metallic (SaaS-specific)

    /// Get tenant usage summary - SaaS subscriptions and consumption
    func getUsageSummary() async throws -> UsageSummaryResponse {
        return try await get(endpoint: "/Metallic/Usage/Summary")
    }

    /// Get detailed usage
    func getUsageDetails() async throws -> Data {
        return try await getRaw(endpoint: "/Metallic/Usage/Details")
    }

    // MARK: - Reports

    /// Get current capacity report
    func getCurrentCapacity() async throws -> Data {
        return try await getRaw(endpoint: "/DashboardTile/CurrentCapacity")
    }

    // MARK: - Network Layer

    private func get<T: Decodable>(endpoint: String) async throws -> T {
        let data = try await getRaw(endpoint: endpoint)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func getRaw(endpoint: String) async throws -> Data {
        let urlString = baseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw CommvaultAPIError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(authToken, forHTTPHeaderField: "Authtoken")
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return data
    }

    private func post<T: Decodable>(url: String, body: [String: Any], authenticated: Bool = true) async throws -> T {
        let data = try await postRawToURL(url: url, body: body, authenticated: authenticated)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func postRaw(endpoint: String, body: [String: Any]) async throws -> Data {
        let urlString = baseURL + endpoint
        return try await postRawToURL(url: urlString, body: body, authenticated: true)
    }

    private func postRawToURL(url: String, body: [String: Any], authenticated: Bool) async throws -> Data {
        guard let url = URL(string: url) else {
            throw CommvaultAPIError.invalidURL(url)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if authenticated {
            request.addValue(authToken, forHTTPHeaderField: "Authtoken")
            request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return data
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

// MARK: - Job Filter

enum JobFilter: String {
    case all = ""
    case failed = "Failed"
    case completed = "Completed"
    case running = "Running"
    case pending = "Pending"
    case killed = "Killed"
    case suspended = "Suspended"
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
            return "Authentication failed. Please check your API key."
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
