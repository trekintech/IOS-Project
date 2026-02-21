import Foundation

// MARK: - Token Renewal

struct TokenRenewRequest: Codable {
    let accessToken: String
    let refreshToken: String
}

struct TokenRenewResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
}

// MARK: - Users

struct UsersResponse: Codable {
    let numberOfUsers: Int?
    let users: [CommvaultUser]?
}

struct CommvaultUser: Codable, Identifiable {
    let id: Int
    let name: String?
    let fullName: String?
    let email: String?
    let userPrincipalName: String?
    let lastLoggedIn: Int?
    let enabled: Bool?
    let description: String?
    let lockInfo: LockInfo?
    let numberOfLaptops: Int?
    let company: CompanyInfo?
    let GUID: String?

    var displayName: String {
        fullName ?? name ?? "Unknown"
    }

    var lastLoginDate: Date? {
        guard let ts = lastLoggedIn, ts > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ts))
    }

    var hasNeverLoggedIn: Bool {
        lastLoggedIn == nil || lastLoggedIn == 0
    }

    var isInactiveOneYear: Bool {
        guard let ts = lastLoggedIn, ts > 0 else { return false }
        let oneYearAgo = Date().addingTimeInterval(-365 * 24 * 60 * 60)
        return Date(timeIntervalSince1970: TimeInterval(ts)) < oneYearAgo
    }
}

struct LockInfo: Codable {
    let isLocked: Bool?
}

struct CompanyInfo: Codable {
    let id: Int?
    let name: String?
}
