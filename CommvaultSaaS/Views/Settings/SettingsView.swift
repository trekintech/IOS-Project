import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Connection Info
                Section {
                    HStack {
                        Label("Ring", systemImage: "globe")
                        Spacer()
                        Text("\(authManager.ringIdentifier).metallic.io")
                            .font(.callout)
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                    if let details = authManager.commCellDetails {
                        if let name = details.commcellName {
                            HStack {
                                Label("CommCell", systemImage: "server.rack")
                                Spacer()
                                Text(name)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let version = details.spVersion {
                            HStack {
                                Label("Version", systemImage: "number")
                                Spacer()
                                Text(version)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Connection")
                }

                // Notification Settings
                Section {
                    Toggle(isOn: $settingsManager.jobFailureNotifications) {
                        Label("Job Failure Alerts", systemImage: "exclamationmark.triangle.fill")
                    }
                    .tint(CommvaultColors.mediumPurple)
                    .onChange(of: settingsManager.jobFailureNotifications) { _, newValue in
                        if newValue {
                            notificationManager.startJobFailureMonitoring(
                                intervalMinutes: settingsManager.jobPollingIntervalMinutes
                            )
                        }
                    }

                    if settingsManager.jobFailureNotifications {
                        Stepper(
                            "Poll every \(settingsManager.jobPollingIntervalMinutes) min",
                            value: $settingsManager.jobPollingIntervalMinutes,
                            in: 5...60,
                            step: 5
                        )
                    }

                    Toggle(isOn: $settingsManager.morningDigestEnabled) {
                        Label("Morning Digest", systemImage: "sunrise.fill")
                    }
                    .tint(CommvaultColors.mediumPurple)
                    .onChange(of: settingsManager.morningDigestEnabled) { _, newValue in
                        if newValue {
                            notificationManager.scheduleMorningDigest(
                                hour: settingsManager.morningDigestHour,
                                minute: settingsManager.morningDigestMinute
                            )
                        }
                    }

                    if settingsManager.morningDigestEnabled {
                        HStack {
                            Label("Delivery Time", systemImage: "clock")
                            Spacer()
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: {
                                        var components = DateComponents()
                                        components.hour = settingsManager.morningDigestHour
                                        components.minute = settingsManager.morningDigestMinute
                                        return Calendar.current.date(from: components) ?? Date()
                                    },
                                    set: { date in
                                        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                                        settingsManager.morningDigestHour = components.hour ?? 7
                                        settingsManager.morningDigestMinute = components.minute ?? 0
                                        notificationManager.scheduleMorningDigest(
                                            hour: settingsManager.morningDigestHour,
                                            minute: settingsManager.morningDigestMinute
                                        )
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }

                    Toggle(isOn: $settingsManager.cohesityTrackingEnabled) {
                        Label("Cohesity Tracking", systemImage: "binoculars.fill")
                    }
                    .tint(CommvaultColors.mediumPurple)
                    .onChange(of: settingsManager.cohesityTrackingEnabled) { _, newValue in
                        if newValue {
                            notificationManager.scheduleCohesityCheck()
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Job failure alerts notify you immediately when backup jobs fail. Morning digest provides an overnight summary. Cohesity tracking monitors competitor features nightly at 10 PM.")
                }

                // Dashboard Settings
                Section {
                    Toggle(isOn: $settingsManager.dashboardAutoRefresh) {
                        Label("Auto-Refresh", systemImage: "arrow.clockwise")
                    }
                    .tint(CommvaultColors.mediumPurple)

                    if settingsManager.dashboardAutoRefresh {
                        Stepper(
                            "Every \(settingsManager.dashboardRefreshSeconds / 60) min",
                            value: $settingsManager.dashboardRefreshSeconds,
                            in: 60...900,
                            step: 60
                        )
                    }
                } header: {
                    Text("Dashboard")
                }

                // About
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: URL(string: "https://api.commvault.com")!) {
                        Label("API Documentation", systemImage: "book")
                    }
                    Link(destination: URL(string: "https://documentation.commvault.com")!) {
                        Label("Product Documentation", systemImage: "doc.text")
                    }
                } header: {
                    Text("About")
                }

                // Logout
                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label("Disconnect", systemImage: "rectangle.portrait.and.arrow.forward")
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Disconnect?", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("This will remove your API key from this device and disconnect from \(authManager.ringIdentifier).metallic.io")
            }
        }
    }
}
