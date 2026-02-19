import SwiftUI

struct RAGChatView: View {
    @StateObject private var ragEngine = RAGEngine()
    @State private var query = ""
    @State private var conversations: [ChatMessage] = []
    @State private var isTyping = false

    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: Role
        let text: String
        let endpoints: [RAGEngine.EndpointInfo]
        let confidence: Double
        let sources: [String]

        enum Role {
            case user, assistant
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat History
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome Message
                            if conversations.isEmpty {
                                WelcomeCard()
                            }

                            ForEach(conversations) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }

                            if isTyping {
                                HStack {
                                    TypingIndicator()
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("typing")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: conversations.count) { _, _ in
                        if let last = conversations.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input Bar
                HStack(spacing: 12) {
                    TextField("Ask about Commvault APIs...", text: $query, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    Button {
                        sendQuery()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                query.isEmpty ? Color(.systemGray4) : CommvaultColors.mediumPurple
                            )
                    }
                    .disabled(query.isEmpty || isTyping)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.regularMaterial)
            }
            .navigationTitle("Ask Commvault")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        conversations.removeAll()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(conversations.isEmpty)
                }
            }
        }
    }

    private func sendQuery() {
        let userQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userQuery.isEmpty else { return }

        conversations.append(ChatMessage(
            role: .user,
            text: userQuery,
            endpoints: [],
            confidence: 1,
            sources: []
        ))
        query = ""
        isTyping = true

        Task {
            let response = await ragEngine.query(userQuery)
            isTyping = false
            conversations.append(ChatMessage(
                role: .assistant,
                text: response.answer,
                endpoints: response.relevantEndpoints,
                confidence: response.confidence,
                sources: response.sources
            ))
        }
    }
}

// MARK: - Chat Components

struct ChatBubble: View {
    let message: RAGChatView.ChatMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // Avatar
                HStack(spacing: 6) {
                    if message.role == .assistant {
                        Image(systemName: "cpu.fill")
                            .font(.caption)
                            .foregroundStyle(CommvaultColors.mediumPurple)
                        Text("Commvault AI")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("You")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(CommvaultColors.deepPurple)
                    }
                }

                // Message Body
                Text(.init(message.text))
                    .font(.body)
                    .padding(12)
                    .background(
                        message.role == .user
                            ? CommvaultColors.deepPurple
                            : Color(.systemGray6)
                    )
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Endpoints (for assistant messages)
                if !message.endpoints.isEmpty && message.role == .assistant {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Endpoints")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        ForEach(message.endpoints.prefix(5), id: \.path) { ep in
                            HStack(spacing: 4) {
                                Text(ep.method)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(methodColor(ep.method))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                Text(ep.path)
                                    .font(.caption2)
                                    .monospaced()
                                    .foregroundStyle(CommvaultColors.deepPurple)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Confidence & Sources
                if message.role == .assistant && message.confidence > 0 {
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Image(systemName: "gauge.medium")
                                .font(.caption2)
                            Text(String(format: "%.0f%% match", message.confidence * 100))
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)

                        if !message.sources.isEmpty {
                            Text(message.sources.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET": return .blue
        case "POST": return .green
        case "PUT", "PATCH": return .orange
        case "DELETE": return .red
        default: return .gray
        }
    }
}

struct WelcomeCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 40))
                .foregroundStyle(CommvaultColors.accentGradient)

            Text("Ask Commvault")
                .font(.title2)
                .fontWeight(.bold)

            Text("Ask questions about the Commvault SaaS API, dashboard operations, job management, and more. Powered by local RAG with embedded documentation.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                SuggestedQuery(text: "How do I authenticate with the API?")
                SuggestedQuery(text: "Show me dashboard health endpoints")
                SuggestedQuery(text: "How do I check failed jobs?")
                SuggestedQuery(text: "What are the SaaS-specific endpoints?")
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

struct SuggestedQuery: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "sparkle")
                .font(.caption2)
                .foregroundStyle(CommvaultColors.hotPink)
            Text(text)
                .font(.callout)
                .foregroundStyle(CommvaultColors.deepPurple)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CommvaultColors.lavender.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct TypingIndicator: View {
    @State private var dotOpacities: [Double] = [0.3, 0.3, 0.3]

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu.fill")
                .font(.caption)
                .foregroundStyle(CommvaultColors.mediumPurple)
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(CommvaultColors.mediumPurple)
                    .frame(width: 6, height: 6)
                    .opacity(dotOpacities[index])
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            animateDots()
        }
    }

    private func animateDots() {
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.5)
                .repeatForever()
                .delay(Double(i) * 0.2)
            ) {
                dotOpacities[i] = 1.0
            }
        }
    }
}
