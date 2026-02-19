import Foundation
import SwiftUI

/// Manages user preferences and app settings with UserDefaults persistence.
@MainActor
final class SettingsManager: ObservableObject {
    @AppStorage("jobFailureNotifications") var jobFailureNotifications = false
    @AppStorage("morningDigestEnabled") var morningDigestEnabled = false
    @AppStorage("morningDigestHour") var morningDigestHour = 7
    @AppStorage("morningDigestMinute") var morningDigestMinute = 0
    @AppStorage("cohesityTrackingEnabled") var cohesityTrackingEnabled = false
    @AppStorage("jobPollingIntervalMinutes") var jobPollingIntervalMinutes = 15
    @AppStorage("dashboardAutoRefresh") var dashboardAutoRefresh = true
    @AppStorage("dashboardRefreshSeconds") var dashboardRefreshSeconds = 300

    /// Get formatted morning digest time string
    var morningDigestTimeString: String {
        let hour = morningDigestHour % 12 == 0 ? 12 : morningDigestHour % 12
        let ampm = morningDigestHour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", hour, morningDigestMinute, ampm)
    }
}
