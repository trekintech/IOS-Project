import Foundation

// MARK: - Authentication

struct LoginResponse: Codable {
    let token: String?
    let authToken: String?
    let userName: String?
    let userGUID: String?
    let aliasName: String?
    let ccn: Int?
    let forcePasswordChange: Bool?
    let isAccountLocked: Bool?
    let errList: [APIError]?

    var effectiveToken: String? {
        token ?? authToken
    }
}

struct APIError: Codable {
    let errorCode: Int?
    let errorMessage: String?
}

/// Response from POST /V4/AccessToken/Renew
struct TokenRenewResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
}

/// Request body for POST /V4/AccessToken/Renew
struct TokenRenewRequest: Codable {
    let accessToken: String
    let refreshToken: String
}

// MARK: - CommCell Details

struct CommCellDetails: Codable {
    let commcellName: String?
    let commcellId: Int?
    let csHostName: String?
    let releaseName: String?
    let spVersion: String?
}

// MARK: - Health Overview

struct HealthOverviewResponse: Codable {
    let totalRecordCount: Int?
    let recordsCount: Int?
    let records: [[HealthRecord]]?
    let columns: [HealthColumn]?
}

struct HealthRecord: Codable {
    let value: String?
    let displayValue: String?
}

struct HealthColumn: Codable {
    let name: String?
    let displayName: String?
    let dataField: String?
}

struct HealthItem: Identifiable {
    let id = UUID()
    let category: String
    let status: HealthStatus
    let count: Int
    let details: String

    enum HealthStatus: String, CaseIterable {
        case good = "Good"
        case info = "Info"
        case warning = "Warning"
        case critical = "Critical"

        var color: String {
            switch self {
            case .good: return "success"
            case .info: return "info"
            case .warning: return "warning"
            case .critical: return "critical"
            }
        }
    }
}

// MARK: - Jobs

struct JobListResponse: Codable {
    let jobs: [JobEntry]?
    let totalRecordsWithoutPaging: Int?
}

struct JobEntry: Codable {
    let jobSummary: JobSummary?
}

struct JobSummary: Codable, Identifiable {
    var id: Int { jobId ?? 0 }
    let jobId: Int?
    let status: String?
    let jobType: String?
    let percentComplete: Int?
    let sizeOfApplication: Int?
    let subclient: SubclientInfo?
    let destClient: ClientInfo?
    let appTypeName: String?
    let jobStartTime: Int?
    let jobEndTime: Int?
    let jobElapsedTime: Int?
    let pendingReason: String?
    let failureReason: String?
    let statusColor: String?

    var startDate: Date? {
        guard let time = jobStartTime else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(time))
    }

    var endDate: Date? {
        guard let time = jobEndTime else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(time))
    }

    var isFailure: Bool {
        status?.lowercased().contains("fail") == true ||
        status?.lowercased().contains("killed") == true
    }

    var isPending: Bool {
        status?.lowercased().contains("pending") == true ||
        status?.lowercased().contains("waiting") == true
    }

    var isRunning: Bool {
        status?.lowercased().contains("running") == true
    }

    var isSuccess: Bool {
        status?.lowercased().contains("completed") == true ||
        status?.lowercased() == "success"
    }
}

struct SubclientInfo: Codable {
    let subclientName: String?
    let clientName: String?
    let instanceName: String?
    let backupsetName: String?
}

struct ClientInfo: Codable {
    let clientName: String?
    let clientId: Int?
}

// MARK: - Job Details

struct JobDetailsResponse: Codable {
    let job: JobDetailEntry?
}

struct JobDetailEntry: Codable {
    let jobDetail: JobDetail?
}

struct JobDetail: Codable {
    let generalInfo: GeneralInfo?
    let progressInfo: ProgressInfo?
}

struct GeneralInfo: Codable {
    let status: String?
    let subclient: SubclientInfo?
    let activity: String?
}

struct ProgressInfo: Codable {
    let percentComplete: Int?
    let pendingTime: Int?
    let totalItems: Int?
    let failedItems: Int?
}

// MARK: - SLA

struct SLAResponse: Codable {
    let totalRecordCount: Int?
    let records: [[SLARecord]]?
}

struct SLARecord: Codable {
    let value: String?
}

// MARK: - Storage

struct StorageUtilizationResponse: Codable {
    let totalRecordCount: Int?
    let records: [[StorageRecord]]?
}

struct StorageRecord: Codable {
    let value: String?
}

// MARK: - Entity Count

struct EntityCountResponse: Codable {
    let entityCounts: [EntityCount]?
}

struct EntityCount: Codable {
    let entityType: String?
    let count: Int?
}

// MARK: - Alerts

struct AlertsResponse: Codable {
    let totalCount: Int?
    let unreadCount: Int?
    let alertsTriggered: [Alert]?
}

struct Alert: Codable, Identifiable {
    var id: Int { alertId ?? UUID().hashValue }
    let alertId: Int?
    let severity: Int?
    let alertType: String?
    let description: String?
    let timeGenerated: Int?
    let isRead: Bool?
    let jobId: Int?
    let clientName: String?

    var generatedDate: Date? {
        guard let time = timeGenerated else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(time))
    }

    var severityLevel: String {
        switch severity {
        case 1: return "Information"
        case 2: return "Warning"
        case 4: return "Critical"
        default: return "Unknown"
        }
    }
}

// MARK: - Usage / Metallic

struct UsageSummaryResponse: Codable {
    let usageSummary: [UsageSummary]?
}

struct UsageSummary: Codable, Identifiable {
    var id: String { offeringName ?? UUID().uuidString }
    let offeringName: String?
    let subscriptionType: String?
    let contractType: String?
    let entitledQuantity: Double?
    let consumedQuantity: Double?
    let unitOfMeasurement: String?
    let startDate: String?
    let endDate: String?
}

// MARK: - Anomalous Entities

struct AnomalousEntitiesResponse: Codable {
    let totalRecordCount: Int?
    let records: [[AnomalousRecord]]?
}

struct AnomalousRecord: Codable {
    let value: String?
}

// MARK: - Jobs in Last 24h

struct Jobs24HResponse: Codable {
    let totalRecordCount: Int?
    let records: [[Jobs24HRecord]]?
}

struct Jobs24HRecord: Codable {
    let value: String?
}

// MARK: - Morning Digest

struct MorningDigest: Identifiable {
    let id = UUID()
    let date: Date
    let totalJobs: Int
    let failedJobs: Int
    let successfulJobs: Int
    let pendingJobs: Int
    let criticalAlerts: Int
    let warningAlerts: Int
    let slaCompliance: Double
    let failedJobDetails: [JobSummary]
    let newAlerts: [Alert]
    let storageUtilization: Double
}

// MARK: - Competitive Intelligence

struct CohesityFeature: Identifiable, Codable {
    var id: String { title + (dateAdded ?? "") }
    let title: String
    let description: String
    let dateAdded: String?
    let category: String?
    let availability: String?  // GA, Private Preview, Controlled Availability
}

struct CohesitySnapshot: Codable {
    let fetchDate: Date
    let features: [CohesityFeature]
    let rawContentHash: String
}
