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
    // Core identity
    let id: Int
    let name: String?
    let displayName: String?
    let hostName: String?

    // Software
    let version: String?
    let OS: String?

    // Status — NOTE: API field is "updateState", not "updateStatus"
    let configured: Bool?
    let updateState: String?
    let networkReadiness: String?
    let isInfrastructure: Bool?
    let isMARoleSet: Bool?
    let isMAPackageInstalled: Bool?

    // Timestamps (Unix seconds, may be Int or Double)
    let installTime: TimeInterval?

    // Relations
    let agents: [ServerAgent]?
    let serverGroups: [ServerGroup]?
    let clientRoles: [ServerClientRole]?     // array of {id, name} objects per schema
    let company: CompanyInfo?
    let region: ServerRegion?
    let additionalProperties: ServerAdditionalProperties?

    private enum CodingKeys: String, CodingKey {
        case id, name, displayName, hostName
        case version, OS
        case configured, updateState, networkReadiness
        case isInfrastructure, isMARoleSet, isMAPackageInstalled
        case installTime
        case agents, serverGroups, clientRoles, company, region
        case additionalProperties
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        hostName = try container.decodeIfPresent(String.self, forKey: .hostName)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        OS = try container.decodeIfPresent(String.self, forKey: .OS)
        configured = try container.decodeIfPresent(Bool.self, forKey: .configured)
        updateState = try container.decodeIfPresent(String.self, forKey: .updateState)
        networkReadiness = try container.decodeIfPresent(String.self, forKey: .networkReadiness)
        isInfrastructure = try container.decodeIfPresent(Bool.self, forKey: .isInfrastructure)
        isMARoleSet = try container.decodeIfPresent(Bool.self, forKey: .isMARoleSet)
        isMAPackageInstalled = try container.decodeIfPresent(Bool.self, forKey: .isMAPackageInstalled)
        agents = try? container.decodeIfPresent([ServerAgent].self, forKey: .agents)
        serverGroups = try? container.decodeIfPresent([ServerGroup].self, forKey: .serverGroups)
        clientRoles = try? container.decodeIfPresent([ServerClientRole].self, forKey: .clientRoles)
        company = try container.decodeIfPresent(CompanyInfo.self, forKey: .company)
        region = try container.decodeIfPresent(ServerRegion.self, forKey: .region)
        additionalProperties = try? container.decodeIfPresent(ServerAdditionalProperties.self, forKey: .additionalProperties)

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

    var isOffline: Bool {
        networkReadiness?.uppercased() == "OFFLINE"
    }

    var isOnline: Bool {
        networkReadiness?.uppercased() == "ONLINE"
    }

    var needsUpdate: Bool {
        updateState?.uppercased() == "NEEDS_UPDATE"
    }

    var isUpToDate: Bool {
        updateState?.uppercased() == "UP_TO_DATE"
    }

    var isApplicable: Bool {
        let state = updateState?.uppercased() ?? ""
        let readiness = networkReadiness?.uppercased() ?? ""
        return state != "NOT_APPLICABLE" && readiness != "NOT_APPLICABLE"
    }

    var healthStatus: ServerHealthStatus {
        if isOffline { return .offline }
        // Any server that is explicitly ONLINE but needs an update → needsAttention
        if isOnline && needsUpdate { return .needsAttention }
        // Any ONLINE server (regardless of updateState) is healthy
        if isOnline { return .healthy }
        return .unknown
    }

    /// Client role names joined for display
    var clientRolesDisplay: String {
        guard let roles = clientRoles, !roles.isEmpty else { return "" }
        return roles.compactMap { $0.name }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// Agent names joined for display
    var agentNamesDisplay: String {
        guard let agentList = agents, !agentList.isEmpty else { return "" }
        return agentList.compactMap { $0.name }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

enum ServerHealthStatus: String, CaseIterable {
    case offline = "Offline"
    case needsAttention = "Needs Attention"
    case healthy = "Healthy"
    case unknown = "Unknown"

    var color: Color {
        switch self {
        case .offline: return Color(hex: "FF3B30")
        case .needsAttention: return Color(hex: "FF9500")
        case .healthy: return Color(hex: "34C759")
        case .unknown: return Color.gray
        }
    }

    var icon: String {
        switch self {
        case .offline: return "xmark.circle.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .healthy: return "checkmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var sortOrder: Int {
        switch self {
        case .offline: return 0
        case .needsAttention: return 1
        case .healthy: return 2
        case .unknown: return 3
        }
    }
}

struct ServerAgent: Codable {
    let id: Int?
    let name: String?
    let applicationSize: Int?
    // Timestamps stored as Int64 in API — decode flexibly
    let lastSuccessfulBackup: TimeInterval?
    let lastSuccessfulAGPBackup: TimeInterval?

    private enum CodingKeys: String, CodingKey {
        case id, name, applicationSize, lastSuccessfulBackup, lastSuccessfulAGPBackup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        applicationSize = try? container.decodeIfPresent(Int.self, forKey: .applicationSize)

        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .lastSuccessfulBackup) {
            lastSuccessfulBackup = TimeInterval(intVal)
        } else if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .lastSuccessfulBackup) {
            lastSuccessfulBackup = doubleVal
        } else {
            lastSuccessfulBackup = nil
        }

        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .lastSuccessfulAGPBackup) {
            lastSuccessfulAGPBackup = TimeInterval(intVal)
        } else if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .lastSuccessfulAGPBackup) {
            lastSuccessfulAGPBackup = doubleVal
        } else {
            lastSuccessfulAGPBackup = nil
        }
    }
}

/// clientRoles is an array of {id, name} objects per the V4/Servers schema
struct ServerClientRole: Codable {
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

/// additionalProperties per V4/Servers schema — only contains vendorType
struct ServerAdditionalProperties: Codable {
    let vendorType: String?
}

// MARK: - Credentials

struct CredentialResponse: Codable {
    let credentialManager: [CommvaultCredential]?
}

struct CommvaultCredential: Codable, Identifiable {
    let id: Int
    let name: String?
    let accountType: String?
    let vendorType: String?
    let authType: String?
    let lastModifiedTime: TimeInterval?

    private enum CodingKeys: String, CodingKey {
        case id, name, accountType, vendorType, authType
        // Try every common Commvault timestamp field name
        case lastModifiedTime, modifiedTime, lastModified, createdTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        accountType = try container.decodeIfPresent(String.self, forKey: .accountType)
        vendorType = try container.decodeIfPresent(String.self, forKey: .vendorType)
        authType = try container.decodeIfPresent(String.self, forKey: .authType)

        // Try multiple timestamp field names in priority order
        let timestampKeys: [CodingKeys] = [.lastModifiedTime, .modifiedTime, .lastModified, .createdTime]
        var resolved: TimeInterval? = nil
        for key in timestampKeys {
            if resolved != nil { break }
            if let intVal = try? container.decodeIfPresent(Int.self, forKey: key) {
                resolved = TimeInterval(intVal)
            } else if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: key) {
                resolved = doubleVal
            } else if let strVal = try? container.decodeIfPresent(String.self, forKey: key),
                      let parsed = Double(strVal) {
                resolved = parsed
            }
        }
        lastModifiedTime = resolved
    }

    // MARK: - Computed

    var displayName: String {
        if let n = name, !n.isEmpty { return n }
        return "Unknown Credential"
    }

    var lastModifiedDate: Date? {
        guard let ts = lastModifiedTime, ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    var daysSinceRotation: Int? {
        guard let date = lastModifiedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day
    }

    var ageBucket: CredentialAgeBucket? {
        guard let days = daysSinceRotation else { return nil }
        if days > 365 { return .overOneYear }
        if days > 180 { return .overSixMonths }
        if days > 90  { return .overNinetyDays }
        return nil
    }

    /// Whether this credential matches the allow-list of tracked types.
    /// Checks both accountType and vendorType; also handles API values
    /// that append a `_TYPE` suffix (e.g. `MICROSOFT_AZURE_TYPE`).
    var isTrackedType: Bool {
        let candidates = [vendorType, accountType].compactMap { $0?.uppercased() }
        for t in candidates {
            if CommvaultCredential.trackedTypes.contains(t) { return true }
            if t.hasSuffix("_TYPE") {
                let stripped = String(t.dropLast(5)) // remove "_TYPE"
                if CommvaultCredential.trackedTypes.contains(stripped) { return true }
            }
        }
        return false
    }

    // MARK: - Allow-list

    static let trackedTypes: Set<String> = [
        "WINDOWSACCOUNT", "LINUXACCOUNT", "SSHACCOUNT", "NDMPACCOUNT",
        "VMWAREACCOUNT", "HYPERVACCOUNT", "DATABASE_ACCOUNT",
        "SQL_SERVER_ACCOUNT", "ORACLE", "SAP_ORACLE", "SAP_HANA",
        "POSTGRESQL", "MYSQL", "DB2", "INFORMIX", "SYBASE", "SAP_MAXDB",
        "GOOGLE_SERVICE_ACCOUNT", "KUBERNETES_SERVICE_ACCOUNT",
        "AZURE_CREDENTIAL", "EXTERNAL_CREDENTIAL", "AZURE_STORAGE_ACCOUNT",
        "STORAGE_ARRAY_ACCOUNT", "AMAZON_S3", "MICROSOFT_AZURE",
        "RACKSPACE_CLOUD_FILES", "EMC_ATMOS", "ATT_SYNAPTIC", "HDS_HCP",
        "OPENSTACK", "AMPLIDATA", "CMCC_ONEST", "VERIZON_CLOUD",
        "GOOGLE_CLOUD", "ALICLOUD_OSS", "HUAWEI_OSS",
        "TELEFONICA_OPEN_CLOUD_OBJECT_STORAGE",
        "ORACLE_CLOUD_INFRASTRUCTURE", "INSPUR_CLOUD", "IBM_CLOUD",
        "KINGSOFT_KS3", "IRON_MOUNTAIN_CLOUD", "S3_COMPATIBLE",
        "AMAZON_GLACIER", "HPE_CATALYST", "CEPH_OBJECT_GATEWAY_S3",
        "CLOUDIAN_HYPERSTORE", "DELL_EMC_ECS_S3",
        "FUJITSU_STORAGE_ETERNUS", "HITACHI_VANTARA_HCP_S3",
        "IBM_CLOUD_S3", "NETAPP_STORAGEGRID", "REVERA_VAULT",
        "SCALITY_RING", "WASABI_HOT_CLOUD_STORAGE", "NUTANIX_BUCKETS",
        "HITACHI_VANTARA_HCP_CLOUD_SCALE_S3", "PURE_STORAGE_FLASHBLADE",
        "VAST_DATA", "SALESFORCE_CONNECTED_APP",
        "SERVICENOW_USER_ACCOUNT", "SERVICENOW_REST_API_KEY",
        "MONGODB_ATLAS_ACCESS_KEY", "DATADOG", "CONNECTWISE_ACCOUNT",
        "AUTOTASK_ACCOUNT", "HALO_ACCOUNT", "WIZ",
    ]
}

enum CredentialAgeBucket: String, CaseIterable {
    case overOneYear = "Over 1 Year"
    case overSixMonths = "Over 6 Months"
    case overNinetyDays = "Over 90 Days"

    var color: Color {
        switch self {
        case .overOneYear:     return Color(hex: "FF3B30")
        case .overSixMonths:   return Color(hex: "FF9500")
        case .overNinetyDays:  return Color(hex: "FFCC00")
        }
    }

    var icon: String {
        switch self {
        case .overOneYear:     return "exclamationmark.shield.fill"
        case .overSixMonths:   return "exclamationmark.triangle.fill"
        case .overNinetyDays:  return "clock.badge.exclamationmark"
        }
    }

    var sortOrder: Int {
        switch self {
        case .overOneYear:     return 0
        case .overSixMonths:   return 1
        case .overNinetyDays:  return 2
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .overOneYear:
            return LinearGradient(
                colors: [Color(hex: "7B1E1E"), Color(hex: "C93030")],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .overSixMonths:
            return LinearGradient(
                colors: [Color(hex: "5C4B1E"), Color(hex: "B8860B")],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .overNinetyDays:
            return LinearGradient(
                colors: [Color(hex: "5C5000"), Color(hex: "B89F0B")],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
