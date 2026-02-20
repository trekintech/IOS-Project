import SwiftUI
import Combine

struct JobsView: View {
    @StateObject private var viewModel = JobsViewModel()
    @State private var selectedFilter: JobFilter = .all
    @State private var selectedJob: JobSummary?
    @State private var showJobDetail = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(
                            [JobFilter.all, .failed, .running, .completed, .pending, .killed],
                            id: \.rawValue
                        ) { filter in
                            FilterChip(
                                label: filter == .all ? "All" : filter.rawValue,
                                isSelected: selectedFilter == filter,
                                count: viewModel.countForFilter(filter)
                            ) {
                                selectedFilter = filter
                                Task { await viewModel.loadJobs(filter: filter) }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))

                Divider()

                // Job List
                if viewModel.isLoading && viewModel.jobs.isEmpty {
                    Spacer()
                    ProgressView("Loading jobs...")
                    Spacer()
                } else if viewModel.jobs.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(CommvaultColors.success)
                        Text("No \(selectedFilter == .all ? "" : selectedFilter.rawValue.lowercased() + " ")jobs found")
                            .font(.headline)
                    }
                    Spacer()
                } else {
                    List(viewModel.jobs) { job in
                        JobRowView(job: job)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedJob = job
                                showJobDetail = true
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Jobs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.loadJobs(filter: selectedFilter) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await viewModel.loadJobs(filter: selectedFilter)
            }
            .sheet(isPresented: $showJobDetail) {
                if let job = selectedJob {
                    JobDetailView(job: job)
                }
            }
            .task {
                await viewModel.loadJobs(filter: selectedFilter)
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class JobsViewModel: ObservableObject {
    @Published var jobs: [JobSummary] = []
    @Published var allJobs: [JobSummary] = []
    @Published var isLoading = false

    private let api = CommvaultAPIService.shared

    func loadJobs(filter: JobFilter = .all) async {
        isLoading = true
        do {
            let response = try await api.getJobs(jobFilter: filter, limit: 100)
            self.jobs = response.jobs?.compactMap { $0.jobSummary } ?? []
            if filter == .all {
                self.allJobs = self.jobs
            }
        } catch {
            // Keep existing data on error
        }
        isLoading = false
    }

    func countForFilter(_ filter: JobFilter) -> Int {
        switch filter {
        case .all: return allJobs.count
        case .failed: return allJobs.filter { $0.isFailure }.count
        case .running: return allJobs.filter { $0.isRunning }.count
        case .completed: return allJobs.filter { $0.isSuccess }.count
        case .pending: return allJobs.filter { $0.isPending }.count
        case .killed: return allJobs.filter { $0.status?.lowercased() == "killed" }.count
        case .suspended: return allJobs.filter { $0.status?.lowercased() == "suspended" }.count
        }
    }
}

// MARK: - Job Row

struct JobRowView: View {
    let job: JobSummary

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("#\(job.jobId ?? 0)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .monospaced()
                        .foregroundStyle(.secondary)

                    Text(job.jobType ?? "Backup")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text(job.subclient?.clientName ?? "Unknown Client")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let reason = job.failureReason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(CommvaultColors.critical)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(job.status ?? "Unknown")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor)
                    .clipShape(Capsule())

                if let startDate = job.startDate {
                    Text(startDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if job.isRunning, let percent = job.percentComplete {
                    ProgressView(value: Double(percent) / 100)
                        .frame(width: 60)
                        .tint(CommvaultColors.info)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        if job.isSuccess { return CommvaultColors.success }
        if job.isFailure { return CommvaultColors.critical }
        if job.isRunning { return CommvaultColors.info }
        if job.isPending { return CommvaultColors.warning }
        return .gray
    }
}

struct FilterChip: View {
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
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? .white.opacity(0.3) : Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? CommvaultColors.mediumPurple : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Job Detail

struct JobDetailView: View {
    let job: JobSummary
    @Environment(\.dismiss) var dismiss
    @State private var isResubmitting = false
    @State private var actionMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Job #\(job.jobId ?? 0)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(job.jobType ?? "Backup")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(job.status ?? "Unknown")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(job.isFailure ? CommvaultColors.critical : (job.isSuccess ? CommvaultColors.success : CommvaultColors.info))
                            .clipShape(Capsule())
                    }

                    Divider()

                    // Details Grid
                    DetailRow(label: "Client", value: job.subclient?.clientName ?? "N/A")
                    DetailRow(label: "Subclient", value: job.subclient?.subclientName ?? "N/A")
                    DetailRow(label: "Instance", value: job.subclient?.instanceName ?? "N/A")
                    DetailRow(label: "Backup Set", value: job.subclient?.backupsetName ?? "N/A")
                    DetailRow(label: "App Type", value: job.appTypeName ?? "N/A")

                    if let start = job.startDate {
                        DetailRow(label: "Started", value: start.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let end = job.endDate {
                        DetailRow(label: "Ended", value: end.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let percent = job.percentComplete {
                        DetailRow(label: "Progress", value: "\(percent)%")
                    }

                    // Failure Reason
                    if let reason = job.failureReason, !reason.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Failure Reason")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(reason)
                                .font(.body)
                                .foregroundStyle(CommvaultColors.critical)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(CommvaultColors.critical.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    if let msg = actionMessage {
                        Text(msg)
                            .font(.callout)
                            .foregroundStyle(CommvaultColors.success)
                            .padding()
                    }

                    // Actions
                    if job.isFailure {
                        Button {
                            Task { await resubmitJob() }
                        } label: {
                            HStack {
                                if isResubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                }
                                Text("Resubmit Job")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(CommvaultColors.mediumPurple)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isResubmitting)
                    }
                }
                .padding()
            }
            .navigationTitle("Job Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func resubmitJob() async {
        guard let jobId = job.jobId else { return }
        isResubmitting = true
        do {
            _ = try await CommvaultAPIService.shared.resubmitJob(jobId: jobId)
            actionMessage = "Job resubmitted successfully"
        } catch {
            actionMessage = "Resubmit failed: \(error.localizedDescription)"
        }
        isResubmitting = false
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.body)
            Spacer()
        }
    }
}
