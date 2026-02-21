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
    let lastLoggedIn: TimeInterval?
    let enabled: Bool?
    let description: String?
    let lockInfo: LockInfo?
    let numberOfLaptops: Int?
    let company: CompanyInfo?
    let GUID: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, fullName, email, userPrincipalName
        case lastLoggedIn, enabled, description, lockInfo
        case numberOfLaptops, company, GUID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        userPrincipalName = try container.decodeIfPresent(String.self, forKey: .userPrincipalName)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        lockInfo = try container.decodeIfPresent(LockInfo.self, forKey: .lockInfo)
        numberOfLaptops = try container.decodeIfPresent(Int.self, forKey: .numberOfLaptops)
        company = try container.decodeIfPresent(CompanyInfo.self, forKey: .company)
        GUID = try container.decodeIfPresent(String.self, forKey: .GUID)

        // Flexible decoding: API may return Int, Double, or String for timestamps
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .lastLoggedIn) {
            lastLoggedIn = TimeInterval(intVal)
        } else if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .lastLoggedIn) {
            lastLoggedIn = doubleVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .lastLoggedIn),
                  let parsed = Double(strVal) {
            lastLoggedIn = parsed
        } else {
            lastLoggedIn = nil
        }
    }

    var displayName: String {
        if let fn = fullName, !fn.isEmpty { return fn }
        if let n = name, !n.isEmpty { return n }
        return "Unknown"
    }

    var lastLoginDate: Date? {
        guard let ts = lastLoggedIn, ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    var hasNeverLoggedIn: Bool {
        lastLoggedIn == nil || lastLoggedIn == 0
    }

    var isInactiveSixMonths: Bool {
        guard let ts = lastLoggedIn, ts > 0 else { return false }
        let sixMonthsAgo = Date().addingTimeInterval(-182.5 * 24 * 60 * 60)
        return Date(timeIntervalSince1970: ts) < sixMonthsAgo
    }

    var isInactiveOneYear: Bool {
        guard let ts = lastLoggedIn, ts > 0 else { return false }
        let oneYearAgo = Date().addingTimeInterval(-365 * 24 * 60 * 60)
        return Date(timeIntervalSince1970: ts) < oneYearAgo
    }
}

struct LockInfo: Codable {
    let isLocked: Bool?
}

struct CompanyInfo: Codable {
    let id: Int?
    let name: String?
}
