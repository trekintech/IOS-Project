import Foundation
import SwiftUI

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

// MARK: - Servers

struct ServersResponse: Codable {
    let totalServers: Int?
    let servers: [CommvaultServer]?
}

struct CommvaultServer: Codable, Identifiable {
    let id: Int
    let name: String?
    let displayName: String?
    let hostName: String?
    let installTime: TimeInterval?
    let version: String?
    let configured: Bool?
    let updateStatus: String?
    let networkReadiness: String?
    let isInfrastructure: Bool?
    let isMARoleSet: Bool?
    let agents: [ServerAgent]?
    let serverGroups: [ServerGroup]?
    let company: CompanyInfo?
    let region: ServerRegion?
    let additionalProperties: ServerAdditionalProperties?
    let clientRoles: [String]?

    private enum CodingKeys: String, CodingKey {
        case id, name, displayName, hostName, installTime, version
        case configured, updateStatus, networkReadiness
        case isInfrastructure, isMARoleSet
        case agents, serverGroups, company, region
        case additionalProperties, clientRoles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        hostName = try container.decodeIfPresent(String.self, forKey: .hostName)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        configured = try container.decodeIfPresent(Bool.self, forKey: .configured)
        updateStatus = try container.decodeIfPresent(String.self, forKey: .updateStatus)
        networkReadiness = try container.decodeIfPresent(String.self, forKey: .networkReadiness)
        isInfrastructure = try container.decodeIfPresent(Bool.self, forKey: .isInfrastructure)
        isMARoleSet = try container.decodeIfPresent(Bool.self, forKey: .isMARoleSet)
        agents = try container.decodeIfPresent([ServerAgent].self, forKey: .agents)
        serverGroups = try container.decodeIfPresent([ServerGroup].self, forKey: .serverGroups)
        company = try container.decodeIfPresent(CompanyInfo.self, forKey: .company)
        region = try container.decodeIfPresent(ServerRegion.self, forKey: .region)
        additionalProperties = try container.decodeIfPresent(ServerAdditionalProperties.self, forKey: .additionalProperties)
        clientRoles = try container.decodeIfPresent([String].self, forKey: .clientRoles)

        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .installTime) {
            installTime = TimeInterval(intVal)
        } else if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .installTime) {
            installTime = doubleVal
        } else {
            installTime = nil
        }
    }

    // MARK: - Computed Properties

    var serverDisplayName: String {
        if let dn = displayName, !dn.isEmpty { return dn }
        if let n = name, !n.isEmpty { return n }
        return "Unknown Server"
    }

    var installDate: Date? {
        guard let ts = installTime, ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    var lastOnlineDate: Date? {
        guard let ts = additionalProperties?.lastOnlineTime, ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    var lastOfflineDate: Date? {
        guard let ts = additionalProperties?.lastOfflineTime, ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    var isOffline: Bool {
        networkReadiness?.uppercased() == "OFFLINE"
    }

    var isOnline: Bool {
        networkReadiness?.uppercased() == "ONLINE"
    }

    var needsUpdate: Bool {
        updateStatus?.uppercased() == "NEEDS_UPDATE"
    }

    var isUpToDate: Bool {
        updateStatus?.uppercased() == "UP_TO_DATE"
    }

    var isApplicable: Bool {
        let status = updateStatus?.uppercased() ?? ""
        let readiness = networkReadiness?.uppercased() ?? ""
        return status != "NOT_APPLICABLE" && readiness != "NOT_APPLICABLE"
    }

    var healthStatus: ServerHealthStatus {
        if isOffline { return .offline }
        if isOnline && needsUpdate { return .needsUpdate }
        if isOnline && isUpToDate { return .healthy }
        return .unknown
    }

    var rolesDisplay: String {
        guard let roles = clientRoles, !roles.isEmpty else { return "No roles" }
        return roles.joined(separator: ", ")
    }
}

enum ServerHealthStatus: String, CaseIterable {
    case offline = "Offline"
    case needsUpdate = "Needs Update"
    case healthy = "Online"
    case unknown = "Unknown"

    var color: Color {
        switch self {
        case .offline: return Color(hex: "FF3B30")
        case .needsUpdate: return Color(hex: "FF9500")
        case .healthy: return Color(hex: "34C759")
        case .unknown: return Color.gray
        }
    }

    var icon: String {
        switch self {
        case .offline: return "xmark.circle.fill"
        case .needsUpdate: return "exclamationmark.triangle.fill"
        case .healthy: return "checkmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var sortOrder: Int {
        switch self {
        case .offline: return 0
        case .needsUpdate: return 1
        case .healthy: return 2
        case .unknown: return 3
        }
    }
}

struct ServerAgent: Codable {
    let id: Int?
    let name: String?
}

struct ServerGroup: Codable {
    let id: Int?
    let name: String?
}

struct ServerRegion: Codable {
    let id: Int?
    let name: String?
    let displayName: String?
}

struct ServerAdditionalProperties: Codable {
    let isClientDeleted: Bool?
    let isInfrastructure: Bool?
    let clientStatus: String?
    let lastOnlineTime: TimeInterval?
    let lastOfflineTime: TimeInterval?
    let osInfo: String?
    let VMGUID: String?
    let vendorType: String?

    private enum CodingKeys: String, CodingKey {
        case isClientDeleted, isInfrastructure, clientStatus
        case lastOnlineTime, lastOfflineTime, osInfo, VMGUID, vendorType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isClientDeleted = try container.decodeIfPresent(Bool.self, forKey: .isClientDeleted)
        isInfrastructure = try container.decodeIfPresent(Bool.self, forKey: .isInfrastructure)
        clientStatus = try container.decodeIfPresent(String.self, forKey: .clientStatus)
        osInfo = try container.decodeIfPresent(String.self, forKey: .osInfo)
        VMGUID = try container.decodeIfPresent(String.self, forKey: .VMGUID)
        vendorType = try container.decodeIfPresent(String.self, forKey: .vendorType)

        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .lastOnlineTime) {
            lastOnlineTime = TimeInterval(intVal)
        } else if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .lastOnlineTime) {
            lastOnlineTime = doubleVal
        } else {
            lastOnlineTime = nil
        }

        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .lastOfflineTime) {
            lastOfflineTime = TimeInterval(intVal)
        } else if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .lastOfflineTime) {
            lastOfflineTime = doubleVal
        } else {
            lastOfflineTime = nil
        }
    }
}
