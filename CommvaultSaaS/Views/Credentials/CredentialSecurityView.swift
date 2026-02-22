import SwiftUI
import Combine

struct CredentialSecurityView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var viewModel = CredentialSecurityViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading credentials...")
                Spacer()
            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await viewModel.loadCredentials(authManager: authManager)
                        }
                    }
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Summary header
                        HStack {
                            Text("\(viewModel.filteredCredentials.count) tracked credentials")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)

                        // Bucket cards
                        ForEach(viewModel.bucketGroups, id: \.bucket) { group in
                            NavigationLink {
                                CredentialListView(
                                    title: group.bucket.rawValue,
                                    credentials: group.credentials
                                )
                            } label: {
                                CredentialBucketCard(
                                    bucket: group.bucket,
                                    count: group.credentials.count,
                                    total: viewModel.filteredCredentials.count
                                )
                            }
                        }

                        // If we have credentials but none ended up in buckets,
                        // show debug info so we can diagnose the field mapping.
                        if !viewModel.filteredCredentials.isEmpty && viewModel.bucketGroups.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.shield")
                                    .font(.largeTitle)
                                    .foregroundStyle(.green)
                                Text("All credentials rotated within 90 days")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 40)
                        }

                        if viewModel.filteredCredentials.isEmpty && viewModel.allCredentials.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "key.slash")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("No credentials found")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 40)
                        }

                        // Debug section — shows when timestamps are missing
                        if let debug = viewModel.debugInfo {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("API Debug")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.orange)

                                Text("Total from API: \(viewModel.allCredentials.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                let withTimestamp = viewModel.filteredCredentials.filter { $0.lastModifiedTime != nil }.count
                                Text("With timestamp: \(withTimestamp) / \(viewModel.filteredCredentials.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Text("First record JSON keys:")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(debug)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Credential Security")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await authManager.renewIfNeeded()
                        await viewModel.loadCredentials(authManager: authManager)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .refreshable {
            await authManager.renewIfNeeded()
            await viewModel.loadCredentials(authManager: authManager)
        }
        .task {
            await authManager.renewIfNeeded()
            await viewModel.loadCredentials(authManager: authManager)
        }
    }
}

// MARK: - View Model

struct CredentialBucketGroup: Identifiable {
    let bucket: CredentialAgeBucket
    let credentials: [CommvaultCredential]
    var id: String { bucket.rawValue }
}

@MainActor
final class CredentialSecurityViewModel: ObservableObject {
    @Published var allCredentials: [CommvaultCredential] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var debugInfo: String?

    private let api = CommvaultAPIService.shared

    /// Only credentials whose accountType/vendorType is in the allow-list
    var filteredCredentials: [CommvaultCredential] {
        allCredentials.filter { $0.isTrackedType }
    }

    /// Mutually-exclusive buckets sorted by severity (>1yr first)
    var bucketGroups: [CredentialBucketGroup] {
        let aged = filteredCredentials.filter { $0.ageBucket != nil }
        let grouped = Dictionary(grouping: aged) { $0.ageBucket! }
        return grouped.map { CredentialBucketGroup(bucket: $0.key, credentials: $0.value) }
            .sorted { $0.bucket.sortOrder < $1.bucket.sortOrder }
    }

    func loadCredentials(authManager: AuthenticationManager) async {
        isLoading = true
        errorMessage = nil
        debugInfo = nil

        do {
            let response = try await api.getCredentials()
            self.allCredentials = response.credentialManager ?? []

            // If no timestamps were decoded, fetch raw JSON to show field names
            let withTimestamp = filteredCredentials.filter { $0.lastModifiedTime != nil }.count
            if withTimestamp == 0 && !filteredCredentials.isEmpty {
                await captureDebugInfo()
            }
        } catch CommvaultAPIError.unauthorized {
            let renewed = await authManager.handleUnauthorized()
            if renewed {
                do {
                    let response = try await api.getCredentials()
                    self.allCredentials = response.credentialManager ?? []
                    let withTimestamp = filteredCredentials.filter { $0.lastModifiedTime != nil }.count
                    if withTimestamp == 0 && !filteredCredentials.isEmpty {
                        await captureDebugInfo()
                    }
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            } else {
                self.errorMessage = "Session expired. Please log out and re-authenticate."
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func captureDebugInfo() async {
        do {
            let rawData = try await api.getCredentialsRaw()
            if let json = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
               let items = json["credentialManager"] as? [[String: Any]],
               let first = items.first {
                // Show top-level keys and their value types
                let lines = first.sorted(by: { $0.key < $1.key }).map { key, val in
                    let typeStr: String
                    if val is [String: Any] { typeStr = "{object}" }
                    else if val is [Any] { typeStr = "[array]" }
                    else if val is Int || val is Double { typeStr = "\(val)" }
                    else if let s = val as? String { typeStr = "\"\(s.prefix(30))\"" }
                    else { typeStr = String(describing: type(of: val)) }
                    return "\(key): \(typeStr)"
                }
                debugInfo = lines.joined(separator: "\n")
            }
        } catch {
            debugInfo = "Failed to fetch raw: \(error.localizedDescription)"
        }
    }
}

// MARK: - Bucket Card

struct CredentialBucketCard: View {
    let bucket: CredentialAgeBucket
    let count: Int
    let total: Int

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total) * 100
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: bucket.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(bucket.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Text(String(format: "%.0f%% of tracked credentials", percentage))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Text("\(count)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(20)
        .background(bucket.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: bucket.color.opacity(0.3), radius: 10, y: 5)
    }
}

// MARK: - Credential List View

struct CredentialListView: View {
    let title: String
    let credentials: [CommvaultCredential]

    @State private var searchText = ""

    private var filteredCredentials: [CommvaultCredential] {
        if searchText.isEmpty { return credentials }
        return credentials.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            ($0.accountType ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.vendorType ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filteredCredentials) { cred in
            VStack(alignment: .leading, spacing: 6) {
                // Name + age badge
                HStack(spacing: 8) {
                    Text(cred.displayName)
                        .font(.body)
                        .fontWeight(.medium)

                    Spacer()

                    if let days = cred.daysSinceRotation {
                        Text("\(days)d ago")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(cred.ageBucket?.color ?? .gray)
                            .clipShape(Capsule())
                    }
                }

                // Detail rows
                VStack(alignment: .leading, spacing: 3) {
                    if let acct = cred.accountType, !acct.isEmpty {
                        CredentialDetailRow(label: "Account Type", value: acct)
                    }
                    if let vendor = cred.vendorType, !vendor.isEmpty {
                        CredentialDetailRow(label: "Vendor Type", value: vendor)
                    }
                    if let auth = cred.authType, !auth.isEmpty {
                        CredentialDetailRow(label: "Auth Type", value: auth)
                    }
                    if let date = cred.lastModifiedDate {
                        CredentialDetailRow(
                            label: "Last Modified",
                            value: date.formatted(.dateTime.month().day().year())
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .searchable(text: $searchText, prompt: "Search credentials")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Credential Detail Row

private struct CredentialDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
