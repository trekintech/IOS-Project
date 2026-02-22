import SwiftUI
import Combine
import UIKit

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text(authManager.ringHost)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .monospaced()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isLoading ? .orange : .green)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isLoading ? "Loading..." : "Connected")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(CommvaultColors.cardGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if !viewModel.isLoading {
                    // Total Users
                    NavigationLink {
                        UserListView(
                            title: "All Users",
                            users: viewModel.allUsers,
                            allowsExport: false
                        )
                    } label: {
                        StatCard(
                            icon: "person.3.fill",
                            title: "Total Users",
                            count: viewModel.totalUsers,
                            color: CommvaultColors.mediumPurple,
                            gradient: LinearGradient(
                                colors: [CommvaultColors.deepPurple, CommvaultColors.navyBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }

                    // Inactive 6+ Months
                    NavigationLink {
                        UserListView(
                            title: "Inactive 6+ Months",
                            users: viewModel.inactiveSixMonthUsers,
                            allowsExport: true
                        )
                    } label: {
                        StatCard(
                            icon: "clock.badge.questionmark",
                            title: "Inactive 6+ Months",
                            count: viewModel.inactiveSixMonthCount,
                            subtitle: "Last login over 6 months ago",
                            color: .orange,
                            gradient: LinearGradient(
                                colors: [Color(hex: "5C4B1E"), Color(hex: "B8860B")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }

                    // Inactive 1+ Year
                    NavigationLink {
                        UserListView(
                            title: "Inactive 1+ Year",
                            users: viewModel.inactiveOneYearUsers,
                            allowsExport: true
                        )
                    } label: {
                        StatCard(
                            icon: "clock.badge.exclamationmark",
                            title: "Inactive 1+ Year",
                            count: viewModel.inactiveOneYearCount,
                            subtitle: "Last login over 12 months ago",
                            color: CommvaultColors.warning,
                            gradient: LinearGradient(
                                colors: [Color(hex: "7B4B1E"), Color(hex: "C97A1E")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }

                    // Never Logged In
                    NavigationLink {
                        UserListView(
                            title: "Never Logged In",
                            users: viewModel.neverLoggedInUsers,
                            allowsExport: true
                        )
                    } label: {
                        StatCard(
                            icon: "person.fill.xmark",
                            title: "Never Logged In",
                            count: viewModel.neverLoggedInCount,
                            subtitle: "No login activity recorded",
                            color: CommvaultColors.critical,
                            gradient: LinearGradient(
                                colors: [Color(hex: "7B1E1E"), Color(hex: "C93030")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("User Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await authManager.renewIfNeeded()
                        await viewModel.loadUsers(authManager: authManager)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .refreshable {
            await authManager.renewIfNeeded()
            await viewModel.loadUsers(authManager: authManager)
        }
        .task {
            await authManager.renewIfNeeded()
            await viewModel.loadUsers(authManager: authManager)
        }
    }
}

// MARK: - View Model

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var allUsers: [CommvaultUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = CommvaultAPIService.shared

    var totalUsers: Int { allUsers.count }

    var inactiveSixMonthUsers: [CommvaultUser] {
        allUsers.filter { $0.isInactiveSixMonths }
    }
    var inactiveSixMonthCount: Int { inactiveSixMonthUsers.count }

    var inactiveOneYearUsers: [CommvaultUser] {
        allUsers.filter { $0.isInactiveOneYear }
    }
    var inactiveOneYearCount: Int { inactiveOneYearUsers.count }

    var neverLoggedInUsers: [CommvaultUser] {
        allUsers.filter { $0.hasNeverLoggedIn }
    }
    var neverLoggedInCount: Int { neverLoggedInUsers.count }

    func loadUsers(authManager: AuthenticationManager) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await api.getUsers()
            self.allUsers = response.users ?? []
        } catch CommvaultAPIError.unauthorized {
            let renewed = await authManager.handleUnauthorized()
            if renewed {
                do {
                    let response = try await api.getUsers()
                    self.allUsers = response.users ?? []
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
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let title: String
    let count: Int
    var subtitle: String? = nil
    let color: Color
    let gradient: LinearGradient

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
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
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: color.opacity(0.3), radius: 10, y: 5)
    }
}

// MARK: - User List View

struct UserListView: View {
    let title: String
    let users: [CommvaultUser]
    var allowsExport: Bool = false

    @State private var searchText = ""
    @State private var showExportOptions = false
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false

    private var filteredUsers: [CommvaultUser] {
        if searchText.isEmpty { return users }
        return users.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            ($0.email ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filteredUsers) { user in
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CommvaultColors.mediumPurple.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Text(initials(for: user.displayName))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(CommvaultColors.mediumPurple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.body)
                        .fontWeight(.medium)

                    if let email = user.email, !email.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let date = user.lastLoginDate {
                        Text("Last login: \(date, format: .dateTime.month().day().year())")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Never logged in")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }

                Spacer()

                if user.enabled == true {
                    Circle().fill(.green).frame(width: 8, height: 8)
                } else {
                    Circle().fill(.gray).frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 4)
        }
        .searchable(text: $searchText, prompt: "Search users")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if allowsExport && !users.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showExportOptions = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .confirmationDialog("Export Summary", isPresented: $showExportOptions, titleVisibility: .visible) {
            Button("Export as CSV") {
                if let url = exportCSV() {
                    shareItems = [url]
                    showShareSheet = true
                }
            }
            Button("Export as PDF") {
                if let url = exportPDF() {
                    shareItems = [url]
                    showShareSheet = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose a format. You can email the file from the share sheet.")
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: shareItems)
        }
    }

    // MARK: - CSV Export

    private func exportCSV() -> URL? {
        var lines = ["Name,Email,Last Login,Status"]
        for user in users {
            let name = csvEscape(user.displayName)
            let email = csvEscape(user.email ?? "")
            let lastLogin: String
            if let date = user.lastLoginDate {
                let fmt = DateFormatter()
                fmt.dateStyle = .medium
                fmt.timeStyle = .none
                lastLogin = fmt.string(from: date)
            } else {
                lastLogin = "Never"
            }
            let status = user.enabled == true ? "Active" : "Disabled"
            lines.append("\(name),\(email),\(lastLogin),\(status)")
        }
        let csv = lines.joined(separator: "\n")
        let fileName = sanitizeFilename(title) + ".csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    // MARK: - PDF Export

    private func exportPDF() -> URL? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let lineHeight: CGFloat = 20
        let headerHeight: CGFloat = 60

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let fileName = sanitizeFilename(title) + ".pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let dateStr: String = {
            let f = DateFormatter(); f.dateStyle = .long; f.timeStyle = .none
            return f.string(from: Date())
        }()

        try? renderer.writePDF(to: url) { ctx in
            var yOffset: CGFloat = margin
            var pageUsersDrawn = 0

            func startNewPage() {
                ctx.beginPage()
                yOffset = margin

                // Header bar
                let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: headerHeight)
                UIColor(CommvaultColors.deepPurple).setFill()
                UIRectFill(headerRect)

                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 16),
                    .foregroundColor: UIColor.white
                ]
                let titleStr = NSAttributedString(string: title + " — User Summary", attributes: titleAttrs)
                titleStr.draw(at: CGPoint(x: margin, y: 20))

                let subtitleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.7)
                ]
                let subStr = NSAttributedString(string: "Generated \(dateStr)  •  \(users.count) users", attributes: subtitleAttrs)
                subStr.draw(at: CGPoint(x: margin, y: 40))

                yOffset = headerHeight + 20

                // Column headers
                drawRow(ctx: ctx, y: yOffset, name: "Name", email: "Email", lastLogin: "Last Login", status: "Status", isHeader: true)
                yOffset += lineHeight + 6

                // Separator
                UIColor(CommvaultColors.deepPurple).withAlphaComponent(0.3).setFill()
                UIRectFill(CGRect(x: margin, y: yOffset, width: pageWidth - margin * 2, height: 1))
                yOffset += 8
            }

            startNewPage()

            for user in users {
                if yOffset + lineHeight > pageHeight - margin {
                    startNewPage()
                }

                let lastLogin: String
                if let date = user.lastLoginDate {
                    let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
                    lastLogin = f.string(from: date)
                } else {
                    lastLogin = "Never"
                }
                let status = user.enabled == true ? "Active" : "Disabled"

                // Zebra stripe
                if pageUsersDrawn % 2 == 0 {
                    UIColor.systemGray6.setFill()
                    UIRectFill(CGRect(x: margin, y: yOffset - 2, width: pageWidth - margin * 2, height: lineHeight + 4))
                }

                drawRow(ctx: ctx, y: yOffset,
                        name: user.displayName,
                        email: user.email ?? "",
                        lastLogin: lastLogin,
                        status: status,
                        isHeader: false)

                yOffset += lineHeight + 4
                pageUsersDrawn += 1
            }
        }

        return url
    }

    private func drawRow(ctx: UIGraphicsPDFRendererContext,
                         y: CGFloat,
                         name: String, email: String,
                         lastLogin: String, status: String,
                         isHeader: Bool) {
        let margin: CGFloat = 40
        let pageWidth: CGFloat = 612
        let usableWidth = pageWidth - margin * 2
        let col0 = margin
        let col1 = margin + usableWidth * 0.30
        let col2 = margin + usableWidth * 0.62
        let col3 = margin + usableWidth * 0.82

        let font = isHeader
            ? UIFont.boldSystemFont(ofSize: 10)
            : UIFont.systemFont(ofSize: 10)
        let color = isHeader ? UIColor(CommvaultColors.deepPurple) : UIColor.label
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]

        NSAttributedString(string: name, attributes: attrs).draw(at: CGPoint(x: col0, y: y))
        NSAttributedString(string: email, attributes: attrs).draw(at: CGPoint(x: col1, y: y))
        NSAttributedString(string: lastLogin, attributes: attrs).draw(at: CGPoint(x: col2, y: y))
        NSAttributedString(string: status, attributes: attrs).draw(at: CGPoint(x: col3, y: y))
    }

    private func sanitizeFilename(_ name: String) -> String {
        let safe = name.components(separatedBy: .init(charactersIn: "/\\:*?\"<>|")).joined(separator: "-")
        return safe.isEmpty ? "UserExport" : safe
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Share Sheet (UIActivityViewController wrapper)

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
