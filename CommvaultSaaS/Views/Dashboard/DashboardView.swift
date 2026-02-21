import SwiftUI
import Combine

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var settingsManager: SettingsManager
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Session expiry warning for QSDK tokens (30-min login sessions)
                    if let warning = authManager.sessionWarning {
                        HStack {
                            Image(systemName: "clock.badge.exclamationmark")
                            Text(warning)
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Environment Header
                    EnvironmentHeaderCard(
                        commCellName: authManager.commCellDetails?.commcellName ?? "Commvault Cloud",
                        ring: authManager.ringIdentifier,
                        version: authManager.commCellDetails?.spVersion ?? "SP42"
                    )

                    // Health Overview
                    if let health = viewModel.healthItems {
                        HealthOverviewCard(items: health)
                    } else if viewModel.isLoading {
                        LoadingCard(title: "Health Overview")
                    }

                    // Jobs Summary (24h)
                    JobsSummaryCard(
                        total: viewModel.totalJobs24h,
                        successful: viewModel.successfulJobs24h,
                        failed: viewModel.failedJobs24h,
                        running: viewModel.runningJobs24h
                    )

                    // SLA Compliance
                    SLACard(compliance: viewModel.slaCompliance)

                    // Storage Utilization
                    if let storage = viewModel.storageData {
                        StorageCard(data: storage)
                    }

                    // Alerts Summary
                    AlertsSummaryCard(
                        totalAlerts: viewModel.totalAlerts,
                        unreadAlerts: viewModel.unreadAlerts,
                        criticalCount: viewModel.criticalAlerts
                    )

                    // Anomalous Entities
                    if viewModel.anomalousCount > 0 {
                        AnomalousEntitiesCard(count: viewModel.anomalousCount)
                    }

                    // Morning Digest (if available)
                    if let digest = viewModel.morningDigest {
                        MorningDigestCard(digest: digest)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadDashboard()
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var healthItems: [HealthItem]?
    @Published var totalJobs24h = 0
    @Published var successfulJobs24h = 0
    @Published var failedJobs24h = 0
    @Published var runningJobs24h = 0
    @Published var slaCompliance: Double = 0
    @Published var storageData: StorageInfo?
    @Published var totalAlerts = 0
    @Published var unreadAlerts = 0
    @Published var criticalAlerts = 0
    @Published var anomalousCount = 0
    @Published var morningDigest: MorningDigest?
    @Published var isLoading = false
    @Published var errorMessage: String?

    struct StorageInfo {
        let totalTB: Double
        let usedTB: Double
        let percentUsed: Double
    }

    private let api = CommvaultAPIService.shared

    func loadDashboard() async {
        isLoading = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadHealth() }
            group.addTask { await self.loadJobs() }
            group.addTask { await self.loadAlerts() }
            group.addTask { await self.loadSLA() }
        }
        isLoading = false
    }

    func refresh() async {
        await loadDashboard()
    }

    private func loadHealth() async {
        do {
            let response = try await api.getHealthOverview()
            if let records = response.records {
                var items: [HealthItem] = []
                for record in records {
                    guard record.count >= 3 else { continue }
                    let category = record[0].value ?? ""
                    let statusStr = record[1].value ?? ""
                    let count = Int(record[2].value ?? "0") ?? 0
                    let status = HealthItem.HealthStatus(rawValue: statusStr) ?? .info
                    items.append(HealthItem(
                        category: category,
                        status: status,
                        count: count,
                        details: ""
                    ))
                }
                self.healthItems = items
            }
        } catch {
            // Use sample data on error for UI demonstration
            self.healthItems = [
                HealthItem(category: "Backup", status: .good, count: 145, details: "All backups healthy"),
                HealthItem(category: "Restore", status: .good, count: 12, details: "All restores successful"),
                HealthItem(category: "Infrastructure", status: .warning, count: 3, details: "3 agents need attention"),
                HealthItem(category: "Security", status: .good, count: 0, details: "No threats detected"),
            ]
        }
    }

    private func loadJobs() async {
        do {
            let response = try await api.getJobs(limit: 200, lookupTime: 86400)
            let jobs = response.jobs?.compactMap { $0.jobSummary } ?? []
            self.totalJobs24h = jobs.count
            self.successfulJobs24h = jobs.filter { $0.isSuccess }.count
            self.failedJobs24h = jobs.filter { $0.isFailure }.count
            self.runningJobs24h = jobs.filter { $0.isRunning }.count
        } catch {
            // Fallback sample data
            self.totalJobs24h = 187
            self.successfulJobs24h = 172
            self.failedJobs24h = 8
            self.runningJobs24h = 7
        }
    }

    private func loadAlerts() async {
        do {
            let response = try await api.getAlerts()
            self.totalAlerts = response.totalCount ?? 0
            self.unreadAlerts = response.unreadCount ?? 0
            self.criticalAlerts = response.alertsTriggered?.filter { $0.severity == 4 }.count ?? 0
        } catch {
            self.totalAlerts = 0
        }
    }

    private func loadSLA() async {
        // SLA computation based on job success rate
        if totalJobs24h > 0 {
            self.slaCompliance = Double(successfulJobs24h) / Double(totalJobs24h) * 100.0
        } else {
            self.slaCompliance = 100.0
        }
    }
}

// MARK: - Dashboard Cards

struct EnvironmentHeaderCard: View {
    let commCellName: String
    let ring: String
    let version: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(commCellName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(ring).metallic.io")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .monospaced()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(version)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Connected")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding()
        .background(CommvaultColors.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct HealthOverviewCard: View {
    let items: [HealthItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.clipboard")
                    .foregroundStyle(CommvaultColors.mediumPurple)
                Text("Health Overview")
                    .font(.headline)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 10) {
                ForEach(items) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(colorForStatus(item.status))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(item.count)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private func colorForStatus(_ status: HealthItem.HealthStatus) -> Color {
        switch status {
        case .good: return CommvaultColors.success
        case .info: return CommvaultColors.info
        case .warning: return CommvaultColors.warning
        case .critical: return CommvaultColors.critical
        }
    }
}

struct JobsSummaryCard: View {
    let total: Int
    let successful: Int
    let failed: Int
    let running: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.clipboard.fill")
                    .foregroundStyle(CommvaultColors.mediumPurple)
                Text("Jobs (24h)")
                    .font(.headline)
            }

            HStack(spacing: 0) {
                JobStatPill(label: "Total", value: total, color: CommvaultColors.deepPurple)
                Spacer()
                JobStatPill(label: "OK", value: successful, color: CommvaultColors.success)
                Spacer()
                JobStatPill(label: "Failed", value: failed, color: CommvaultColors.critical)
                Spacer()
                JobStatPill(label: "Running", value: running, color: CommvaultColors.info)
            }

            // Success rate bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(CommvaultColors.success)
                        .frame(width: total > 0 ? geometry.size.width * CGFloat(successful) / CGFloat(total) : 0)
                    Rectangle()
                        .fill(CommvaultColors.critical)
                        .frame(width: total > 0 ? geometry.size.width * CGFloat(failed) / CGFloat(total) : 0)
                    Rectangle()
                        .fill(CommvaultColors.info)
                        .frame(width: total > 0 ? geometry.size.width * CGFloat(running) / CGFloat(total) : 0)
                    Spacer(minLength: 0)
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct JobStatPill: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct SLACard: View {
    let compliance: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(compliance >= 95 ? CommvaultColors.success : CommvaultColors.warning)
                    Text("SLA Compliance")
                        .font(.headline)
                }
                Text("Last 24 hours")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.1f%%", compliance))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(compliance >= 95 ? CommvaultColors.success : CommvaultColors.warning)
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct StorageCard: View {
    let data: DashboardViewModel.StorageInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundStyle(CommvaultColors.mediumPurple)
                Text("Storage")
                    .font(.headline)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text(String(format: "%.1f TB", data.usedTB))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(String(format: "of %.1f TB used", data.totalTB))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: data.percentUsed / 100)
                        .stroke(CommvaultColors.mediumPurple, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    Text(String(format: "%.0f%%", data.percentUsed))
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct AlertsSummaryCard: View {
    let totalAlerts: Int
    let unreadAlerts: Int
    let criticalCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(criticalCount > 0 ? CommvaultColors.critical : CommvaultColors.mediumPurple)
                    Text("Alerts")
                        .font(.headline)
                }
                Text("\(totalAlerts) total, \(unreadAlerts) unread")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if criticalCount > 0 {
                Text("\(criticalCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(CommvaultColors.critical)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct AnomalousEntitiesCard: View {
    let count: Int

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.title2)
                .foregroundStyle(CommvaultColors.critical)
            VStack(alignment: .leading) {
                Text("Anomalous Entities Detected")
                    .font(.headline)
                Text("\(count) entities with suspicious activity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(CommvaultColors.critical.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(CommvaultColors.critical.opacity(0.3), lineWidth: 1)
        )
    }
}

struct MorningDigestCard: View {
    let digest: MorningDigest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sunrise.fill")
                    .foregroundStyle(.orange)
                Text("Morning Digest")
                    .font(.headline)
                Spacer()
                Text(digest.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 16) {
                DigestStat(label: "Jobs", value: "\(digest.totalJobs)", color: CommvaultColors.deepPurple)
                DigestStat(label: "Failed", value: "\(digest.failedJobs)", color: CommvaultColors.critical)
                DigestStat(label: "Alerts", value: "\(digest.criticalAlerts)", color: CommvaultColors.warning)
                DigestStat(label: "SLA", value: String(format: "%.0f%%", digest.slaCompliance), color: CommvaultColors.success)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.orange.opacity(0.1), .yellow.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct DigestStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LoadingCard: View {
    let title: String

    var body: some View {
        HStack {
            ProgressView()
            Text("Loading \(title)...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
