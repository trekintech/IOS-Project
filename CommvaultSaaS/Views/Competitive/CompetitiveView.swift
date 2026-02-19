import SwiftUI

struct CompetitiveView: View {
    @StateObject private var monitor = CohesityMonitorService()
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var selectedCategory: String = "All"

    private var categories: [String] {
        var cats = Set(monitor.features.compactMap { $0.category })
        cats.insert("All")
        return ["All"] + cats.sorted().filter { $0 != "All" }
    }

    private var filteredFeatures: [CohesityFeature] {
        if selectedCategory == "All" {
            return monitor.features
        }
        return monitor.features.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Cohesity Tracker")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Competitive Intelligence")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            if let lastChecked = monitor.lastChecked {
                                Text("Last checked")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                                Text(lastChecked, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }

                    if !monitor.newFeatures.isEmpty {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("\(monitor.newFeatures.count) new feature(s) detected")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
                .background(CommvaultColors.cardGradient)

                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            CategoryPill(
                                label: category,
                                isSelected: selectedCategory == category,
                                count: category == "All"
                                    ? monitor.features.count
                                    : monitor.features.filter { $0.category == category }.count
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Divider()

                // Feature List
                if monitor.isChecking {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Scanning Cohesity updates...")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else if filteredFeatures.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "binoculars")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No features to display")
                            .font(.headline)
                        Text("Pull down or tap the scan button to check for updates")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    List(filteredFeatures) { feature in
                        FeatureRowView(feature: feature, isNew: monitor.newFeatures.contains(where: { $0.id == feature.id }))
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                }

                if let error = monitor.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                    }
                    .padding()
                    .background(.orange.opacity(0.1))
                }
            }
            .navigationTitle("Competitive Intel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            let newFeatures = await monitor.checkForNewFeatures()
                            if !newFeatures.isEmpty {
                                await notificationManager.sendCohesityUpdateNotification(features: newFeatures)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(monitor.isChecking)
                }
            }
            .refreshable {
                let newFeatures = await monitor.checkForNewFeatures()
                if !newFeatures.isEmpty {
                    await notificationManager.sendCohesityUpdateNotification(features: newFeatures)
                }
            }
        }
    }
}

struct CategoryPill: View {
    let label: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .medium)
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(isSelected ? .white.opacity(0.3) : Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? CommvaultColors.navyBlue : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

struct FeatureRowView: View {
    let feature: CohesityFeature
    let isNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isNew {
                    Text("NEW")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(CommvaultColors.hotPink)
                        .clipShape(Capsule())
                }

                if let availability = feature.availability, availability != "GA" {
                    Text(availability)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.1))
                        .clipShape(Capsule())
                }

                if let category = feature.category {
                    Text(category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }

            Text(feature.title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(feature.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if let date = feature.dateAdded {
                Text(date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
