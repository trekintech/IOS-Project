import Foundation
import Combine
import SwiftUI

/// Monitors the Cohesity "What's New" page for new features and sends competitive intelligence notifications.
@MainActor
final class CohesityMonitorService: ObservableObject {
    @Published var features: [CohesityFeature] = []
    @Published var newFeatures: [CohesityFeature] = []
    @Published var lastChecked: Date?
    @Published var isChecking = false
    @Published var errorMessage: String?

    private let cohesityURL = "https://docs.cohesity.com/baas/data-protect/whatsnew.htm"
    private let storageKey = "cohesity_snapshot"

    init() {
        loadStoredSnapshot()
    }

    // MARK: - Feature Checking

    /// Fetch the Cohesity What's New page and detect new features
    func checkForNewFeatures() async -> [CohesityFeature] {
        isChecking = true
        errorMessage = nil
        defer { isChecking = false }

        do {
            guard let url = URL(string: cohesityURL) else {
                errorMessage = "Invalid Cohesity URL"
                return []
            }

            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                errorMessage = "Failed to decode Cohesity page"
                return []
            }

            let parsedFeatures = parseFeatures(from: html)
            let previousFeatures = loadStoredFeatures()

            // Find new features by comparing titles
            let previousTitles = Set(previousFeatures.map { $0.title })
            let detected = parsedFeatures.filter { !previousTitles.contains($0.title) }

            // Store new snapshot
            let snapshot = CohesitySnapshot(
                fetchDate: Date(),
                features: parsedFeatures,
                rawContentHash: String(html.hashValue)
            )
            saveSnapshot(snapshot)

            self.features = parsedFeatures
            self.newFeatures = detected
            self.lastChecked = Date()

            return detected
        } catch {
            errorMessage = "Failed to check Cohesity: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - HTML Parsing

    private func parseFeatures(from html: String) -> [CohesityFeature] {
        var features: [CohesityFeature] = []
        var currentMonth = ""

        // Parse by looking for month/year headers and bullet points
        let lines = html.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Detect month headers (e.g., "January 2026", "December 2025")
            if let monthMatch = extractMonthYear(from: trimmed) {
                currentMonth = monthMatch
                continue
            }

            // Detect feature entries - look for list items or bold text patterns
            if let feature = extractFeature(from: trimmed, month: currentMonth) {
                features.append(feature)
            }
        }

        // If HTML parsing didn't yield results, try a broader approach
        if features.isEmpty {
            features = parseFeaturesFromHTML(html)
        }

        return features
    }

    private func extractMonthYear(from text: String) -> String? {
        let months = ["January", "February", "March", "April", "May", "June",
                      "July", "August", "September", "October", "November", "December"]
        let stripped = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for month in months {
            if stripped.contains(month), stripped.range(of: #"\d{4}"#, options: .regularExpression) != nil {
                return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func extractFeature(from text: String, month: String) -> CohesityFeature? {
        let stripped = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard stripped.count > 20, // Meaningful content
              !stripped.hasPrefix("<!"),
              !stripped.hasPrefix("var "),
              !stripped.hasPrefix("function"),
              !stripped.hasPrefix("//") else {
            return nil
        }

        // Look for feature-like content (contains action words)
        let featureIndicators = ["support", "protect", "backup", "recover", "enable", "enhance",
                                 "new", "add", "improv", "updat", "introduc", "deploy", "monitor"]
        let hasFeatureIndicator = featureIndicators.contains { stripped.lowercased().contains($0) }
        guard hasFeatureIndicator else { return nil }

        // Determine availability
        var availability = "GA"
        if stripped.contains("Private Preview") { availability = "Private Preview" }
        if stripped.contains("Controlled Availability") { availability = "Controlled Availability" }
        if stripped.contains("Early Access") { availability = "Early Access" }

        // Extract title (first sentence or up to first period)
        let title = stripped.components(separatedBy: ".").first ?? stripped
        let description = stripped

        return CohesityFeature(
            title: String(title.prefix(120)),
            description: description,
            dateAdded: month,
            category: categorizeFeature(stripped),
            availability: availability
        )
    }

    private func parseFeaturesFromHTML(_ html: String) -> [CohesityFeature] {
        var features: [CohesityFeature] = []

        // Extract content between <li> tags or <p> tags that contain feature descriptions
        let patterns = [
            #"<li[^>]*>(.*?)</li>"#,
            #"<p[^>]*class="[^"]*feature[^"]*"[^>]*>(.*?)</p>"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { continue }
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

            for match in matches {
                guard let range = Range(match.range(at: 1), in: html) else { continue }
                let content = String(html[range])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if content.count > 20 && content.count < 500 {
                    features.append(CohesityFeature(
                        title: String(content.prefix(120)),
                        description: content,
                        dateAdded: nil,
                        category: categorizeFeature(content),
                        availability: "GA"
                    ))
                }
            }
        }

        return features
    }

    private func categorizeFeature(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("microsoft") || lower.contains("m365") || lower.contains("exchange") || lower.contains("onedrive") || lower.contains("sharepoint") || lower.contains("teams") {
            return "Microsoft 365"
        }
        if lower.contains("aws") || lower.contains("amazon") || lower.contains("ec2") || lower.contains("rds") || lower.contains("s3") {
            return "AWS"
        }
        if lower.contains("azure") || lower.contains("entra") {
            return "Azure"
        }
        if lower.contains("vmware") || lower.contains("hyper-v") || lower.contains("kubernetes") || lower.contains("k8s") {
            return "Infrastructure"
        }
        if lower.contains("security") || lower.contains("ransomware") || lower.contains("threat") || lower.contains("encrypt") {
            return "Security"
        }
        if lower.contains("report") || lower.contains("dashboard") || lower.contains("monitor") {
            return "Reporting"
        }
        if lower.contains("sql") || lower.contains("oracle") || lower.contains("sap") || lower.contains("database") {
            return "Databases"
        }
        return "General"
    }

    // MARK: - Persistence

    private func saveSnapshot(_ snapshot: CohesitySnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadStoredSnapshot() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(CohesitySnapshot.self, from: data) else {
            return
        }
        self.features = snapshot.features
        self.lastChecked = snapshot.fetchDate
    }

    private func loadStoredFeatures() -> [CohesityFeature] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(CohesitySnapshot.self, from: data) else {
            return []
        }
        return snapshot.features
    }
}
