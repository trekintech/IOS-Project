import Foundation
import BackgroundTasks
import UserNotifications

/// Background task handler for periodic job monitoring and morning digest generation.
/// Registers BGTaskScheduler tasks for iOS background processing.
final class BackgroundJobMonitor {
    static let shared = BackgroundJobMonitor()
    static let jobCheckTaskIdentifier = "com.commvault.saas.jobcheck"
    static let digestTaskIdentifier = "com.commvault.saas.morningdigest"
    static let cohesityTaskIdentifier = "com.commvault.saas.cohesitycheck"

    private init() {}

    /// Register all background tasks with BGTaskScheduler
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.jobCheckTaskIdentifier,
            using: nil
        ) { task in
            self.handleJobCheck(task: task as! BGAppRefreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.digestTaskIdentifier,
            using: nil
        ) { task in
            self.handleMorningDigest(task: task as! BGProcessingTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.cohesityTaskIdentifier,
            using: nil
        ) { task in
            self.handleCohesityCheck(task: task as! BGProcessingTask)
        }
    }

    /// Schedule the next job check (every 15 minutes)
    func scheduleJobCheck() {
        let request = BGAppRefreshTaskRequest(identifier: Self.jobCheckTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Schedule morning digest (daily at configured time)
    func scheduleMorningDigest(hour: Int = 7, minute: Int = 0) {
        let request = BGProcessingTaskRequest(identifier: Self.digestTaskIdentifier)
        request.requiresNetworkConnectivity = true

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        if let nextDate = Calendar.current.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) {
            request.earliestBeginDate = nextDate
        }
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Schedule nightly Cohesity check (daily at 10 PM)
    func scheduleCohesityCheck() {
        let request = BGProcessingTaskRequest(identifier: Self.cohesityTaskIdentifier)
        request.requiresNetworkConnectivity = true

        var components = DateComponents()
        components.hour = 22
        components.minute = 0
        if let nextDate = Calendar.current.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) {
            request.earliestBeginDate = nextDate
        }
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Task Handlers

    private func handleJobCheck(task: BGAppRefreshTask) {
        scheduleJobCheck() // Schedule next check

        let operation = Task {
            let api = CommvaultAPIService.shared
            do {
                let response = try await api.getJobs(jobFilter: .failed, limit: 10, lookupTime: 900)
                guard let jobs = response.jobs, !jobs.isEmpty else {
                    task.setTaskCompleted(success: true)
                    return
                }

                let failedJobs = jobs.compactMap { $0.jobSummary }.filter { $0.isFailure }
                for job in failedJobs {
                    await sendJobFailureNotification(job: job)
                }
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            operation.cancel()
        }
    }

    private func handleMorningDigest(task: BGProcessingTask) {
        scheduleMorningDigest() // Schedule next digest

        let operation = Task {
            let api = CommvaultAPIService.shared
            do {
                let jobsResponse = try await api.getJobs(limit: 200, lookupTime: 43200)
                let alertsResponse = try await api.getAlerts(pageSize: 100)

                let allJobs = jobsResponse.jobs?.compactMap { $0.jobSummary } ?? []
                let failedCount = allJobs.filter { $0.isFailure }.count
                let successCount = allJobs.filter { $0.isSuccess }.count
                let criticalCount = alertsResponse.alertsTriggered?.filter { $0.severity == 4 }.count ?? 0

                let sla = allJobs.isEmpty ? 100.0 : Double(successCount) / Double(allJobs.count) * 100

                let content = UNMutableNotificationContent()
                content.title = "Overnight Summary"
                content.body = "\(allJobs.count) jobs | \(failedCount) failed | \(criticalCount) critical alerts | SLA: \(String(format: "%.0f", sla))%"
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: "morning-digest-\(Date().timeIntervalSince1970)",
                    content: content,
                    trigger: nil
                )
                try? await UNUserNotificationCenter.current().add(request)
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            operation.cancel()
        }
    }

    private func handleCohesityCheck(task: BGProcessingTask) {
        scheduleCohesityCheck() // Schedule next check

        let operation = Task { @MainActor in
            let monitor = CohesityMonitorService()
            let newFeatures = await monitor.checkForNewFeatures()

            if !newFeatures.isEmpty {
                let content = UNMutableNotificationContent()
                content.title = "Cohesity: \(newFeatures.count) New Feature(s)"
                content.body = newFeatures.prefix(3).map { $0.title }.joined(separator: "\n")
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: "cohesity-\(Date().timeIntervalSince1970)",
                    content: content,
                    trigger: nil
                )
                try? await UNUserNotificationCenter.current().add(request)
            }
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            operation.cancel()
        }
    }

    private func sendJobFailureNotification(job: JobSummary) async {
        let content = UNMutableNotificationContent()
        content.title = "Job Failed"
        content.subtitle = job.subclient?.clientName ?? "Unknown"
        content.body = "Job #\(job.jobId ?? 0) (\(job.jobType ?? "Backup")) - \(job.failureReason ?? "No details")"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "job-bg-\(job.jobId ?? 0)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
