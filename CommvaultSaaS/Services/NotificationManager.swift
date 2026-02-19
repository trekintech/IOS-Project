import Foundation
import UserNotifications
import SwiftUI

/// Manages push notifications for job failures, morning digests, and competitive intelligence.
@MainActor
final class NotificationManager: ObservableObject {
    @Published var permissionGranted = false
    @Published var lastDigest: MorningDigest?

    private let center = UNUserNotificationCenter.current()
    private let api = CommvaultAPIService.shared

    // MARK: - Permission

    func requestPermission() {
        Task {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                self.permissionGranted = granted
            } catch {
                print("Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Job Failure Monitoring

    /// Start polling for job failures at the configured interval
    func startJobFailureMonitoring(intervalMinutes: Int = 15) {
        Task {
            while true {
                await checkForJobFailures()
                try? await Task.sleep(for: .seconds(intervalMinutes * 60))
            }
        }
    }

    private func checkForJobFailures() async {
        do {
            let response = try await api.getJobs(jobFilter: .failed, limit: 10, lookupTime: 900) // last 15 min
            guard let jobs = response.jobs, !jobs.isEmpty else { return }

            let failedJobs = jobs.compactMap { $0.jobSummary }.filter { $0.isFailure }
            for job in failedJobs {
                await sendJobFailureNotification(job: job)
            }
        } catch {
            // Silently fail - will retry next interval
        }
    }

    private func sendJobFailureNotification(job: JobSummary) async {
        let content = UNMutableNotificationContent()
        content.title = "Job Failed"
        content.subtitle = job.subclient?.clientName ?? "Unknown Client"
        content.body = "Job #\(job.jobId ?? 0) (\(job.jobType ?? "Backup")) failed. \(job.failureReason ?? "")"
        content.sound = .default
        content.categoryIdentifier = "JOB_FAILURE"
        content.userInfo = ["jobId": job.jobId ?? 0]

        let request = UNNotificationRequest(
            identifier: "job-failure-\(job.jobId ?? 0)",
            content: content,
            trigger: nil // Immediate
        )
        try? await center.add(request)
    }

    // MARK: - Morning Digest

    func scheduleMorningDigest(hour: Int = 7, minute: Int = 0) {
        // Remove existing morning digest notifications
        center.removePendingNotificationRequests(withIdentifiers: ["morning-digest"])

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Commvault Morning Digest"
        content.body = "Tap to view your overnight summary"
        content.sound = .default
        content.categoryIdentifier = "MORNING_DIGEST"

        let request = UNNotificationRequest(
            identifier: "morning-digest",
            content: content,
            trigger: trigger
        )
        Task {
            try? await center.add(request)
        }
    }

    /// Generate the morning digest data by querying the API
    func generateMorningDigest() async -> MorningDigest? {
        do {
            // Fetch overnight data (last 12 hours)
            let jobsResponse = try await api.getJobs(limit: 200, lookupTime: 43200)
            let alertsResponse = try await api.getAlerts(pageSize: 100)

            let allJobs = jobsResponse.jobs?.compactMap { $0.jobSummary } ?? []
            let failedJobs = allJobs.filter { $0.isFailure }
            let successJobs = allJobs.filter { $0.isSuccess }
            let pendingJobs = allJobs.filter { $0.isPending }

            let allAlerts = alertsResponse.alertsTriggered ?? []
            let criticalAlerts = allAlerts.filter { $0.severity == 4 }
            let warningAlerts = allAlerts.filter { $0.severity == 2 }

            let slaCompliance = successJobs.isEmpty && allJobs.isEmpty
                ? 100.0
                : Double(successJobs.count) / Double(max(allJobs.count, 1)) * 100.0

            let digest = MorningDigest(
                date: Date(),
                totalJobs: allJobs.count,
                failedJobs: failedJobs.count,
                successfulJobs: successJobs.count,
                pendingJobs: pendingJobs.count,
                criticalAlerts: criticalAlerts.count,
                warningAlerts: warningAlerts.count,
                slaCompliance: slaCompliance,
                failedJobDetails: failedJobs,
                newAlerts: allAlerts,
                storageUtilization: 0
            )

            lastDigest = digest

            // Send summary notification
            await sendDigestNotification(digest: digest)

            return digest
        } catch {
            return nil
        }
    }

    private func sendDigestNotification(digest: MorningDigest) async {
        let content = UNMutableNotificationContent()
        content.title = "Overnight Summary"

        var bodyParts: [String] = []
        bodyParts.append("\(digest.totalJobs) jobs processed")
        if digest.failedJobs > 0 {
            bodyParts.append("\(digest.failedJobs) failures")
        }
        if digest.criticalAlerts > 0 {
            bodyParts.append("\(digest.criticalAlerts) critical alerts")
        }
        bodyParts.append(String(format: "SLA: %.0f%%", digest.slaCompliance))

        content.body = bodyParts.joined(separator: " | ")
        content.sound = .default
        content.categoryIdentifier = "MORNING_DIGEST"

        let request = UNNotificationRequest(
            identifier: "digest-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    // MARK: - Cohesity Competitive Intelligence

    func scheduleCohesityCheck() {
        center.removePendingNotificationRequests(withIdentifiers: ["cohesity-check"])

        // Schedule nightly at 10 PM
        var dateComponents = DateComponents()
        dateComponents.hour = 22
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Competitive Intel Check"
        content.body = "Running nightly Cohesity feature scan..."
        content.sound = .default
        content.categoryIdentifier = "COHESITY_CHECK"

        let request = UNNotificationRequest(
            identifier: "cohesity-check",
            content: content,
            trigger: trigger
        )
        Task {
            try? await center.add(request)
        }
    }

    func sendCohesityUpdateNotification(features: [CohesityFeature]) async {
        guard !features.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Cohesity New Features Detected"
        content.subtitle = "\(features.count) new feature(s) found"
        content.body = features.prefix(3).map { $0.title }.joined(separator: "\n")
        content.sound = .default
        content.categoryIdentifier = "COHESITY_UPDATE"

        let request = UNNotificationRequest(
            identifier: "cohesity-update-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
