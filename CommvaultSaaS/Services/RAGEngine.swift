import Foundation
import Combine
import NaturalLanguage

/// Local Retrieval-Augmented Generation engine for answering questions about
/// Commvault SaaS using embedded API documentation.
/// Uses on-device NLP for keyword extraction and TF-IDF style scoring.
@MainActor
final class RAGEngine: ObservableObject {
    @Published var isProcessing = false

    private var knowledgeBase: [KnowledgeSection] = []
    private var invertedIndex: [String: Set<Int>] = [:]
    private var documentFrequencies: [String: Int] = [:]
    private let tokenizer = NLTokenizer(unit: .word)
    private let lemmatizer = NLTagger(tagSchemes: [.lemma])

    struct KnowledgeSection {
        let topic: String
        let category: String
        let content: String
        let endpoints: [EndpointInfo]
        let keywords: [String]
        let tokens: [String]
    }

    struct EndpointInfo {
        let method: String
        let path: String
        let description: String
    }

    struct RAGResponse {
        let answer: String
        let relevantEndpoints: [EndpointInfo]
        let confidence: Double
        let sources: [String]
    }

    init() {
        loadKnowledgeBase()
    }

    // MARK: - Knowledge Base Loading

    private func loadKnowledgeBase() {
        guard let url = Bundle.main.url(forResource: "CommvaultAPIKnowledgeBase", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            loadFallbackKnowledge()
            return
        }
        parseKnowledgeBase(data: data)
    }

    private func loadFallbackKnowledge() {
        // Embedded fallback if bundle resource unavailable
        let json = createEmbeddedKnowledgeJSON()
        guard let data = json.data(using: .utf8) else { return }
        parseKnowledgeBase(data: data)
    }

    private func parseKnowledgeBase(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = json["sections"] as? [[String: Any]] else {
            return
        }

        knowledgeBase = sections.enumerated().map { index, section in
            let endpoints = (section["endpoints"] as? [[String: String]])?.map { ep in
                EndpointInfo(
                    method: ep["method"] ?? "",
                    path: ep["path"] ?? "",
                    description: ep["description"] ?? ""
                )
            } ?? []

            let content = section["content"] as? String ?? ""
            let keywords = section["keywords"] as? [String] ?? []
            let tokens = tokenize(content) + keywords.flatMap { tokenize($0) }

            return KnowledgeSection(
                topic: section["topic"] as? String ?? "",
                category: section["category"] as? String ?? "",
                content: content,
                endpoints: endpoints,
                keywords: keywords,
                tokens: tokens
            )
        }

        buildIndex()
    }

    // MARK: - Indexing

    private func buildIndex() {
        invertedIndex.removeAll()
        documentFrequencies.removeAll()

        for (docIndex, section) in knowledgeBase.enumerated() {
            var uniqueTokens = Set<String>()
            for token in section.tokens {
                let normalized = token.lowercased()
                if invertedIndex[normalized] == nil {
                    invertedIndex[normalized] = Set<Int>()
                }
                invertedIndex[normalized]?.insert(docIndex)
                uniqueTokens.insert(normalized)
            }
            for token in uniqueTokens {
                documentFrequencies[token, default: 0] += 1
            }
        }
    }

    // MARK: - Query Processing

    func query(_ question: String) async -> RAGResponse {
        isProcessing = true
        defer { isProcessing = false }

        let queryTokens = tokenize(question)
        let queryLemmas = lemmatize(question)
        let allQueryTerms = Set(queryTokens + queryLemmas)

        // Score each document using TF-IDF-like scoring
        var scores: [(index: Int, score: Double)] = []
        let totalDocs = Double(knowledgeBase.count)

        for (docIndex, section) in knowledgeBase.enumerated() {
            var score: Double = 0
            let docLength = Double(max(section.tokens.count, 1))

            for term in allQueryTerms {
                let termLower = term.lowercased()

                // Term frequency in document
                let tf = Double(section.tokens.filter { $0.lowercased() == termLower }.count) / docLength

                // Inverse document frequency
                let df = Double(documentFrequencies[termLower] ?? 0)
                let idf = df > 0 ? log(totalDocs / df) + 1.0 : 0

                score += tf * idf

                // Keyword boost: if query term matches a keyword, boost significantly
                if section.keywords.contains(where: { $0.lowercased().contains(termLower) }) {
                    score += 2.0
                }

                // Exact phrase match in content boost
                if section.content.lowercased().contains(termLower) {
                    score += 0.5
                }
            }

            // Boost for category relevance
            if allQueryTerms.contains("saas") || allQueryTerms.contains("metallic") || allQueryTerms.contains("cloud") {
                if section.category == "saas" { score += 3.0 }
            }
            if allQueryTerms.contains("job") || allQueryTerms.contains("backup") || allQueryTerms.contains("restore") {
                if section.category == "core" && section.topic.contains("Job") { score += 3.0 }
            }

            if score > 0 {
                scores.append((index: docIndex, score: score))
            }
        }

        scores.sort { $0.score > $1.score }

        // Select top relevant sections
        let topSections = scores.prefix(3)

        guard !topSections.isEmpty else {
            return RAGResponse(
                answer: "I don't have specific information about that in my Commvault API knowledge base. Try asking about: dashboard health, jobs, alerts, SaaS usage, authentication, or storage.",
                relevantEndpoints: [],
                confidence: 0,
                sources: []
            )
        }

        // Build response
        let maxScore = topSections.first?.score ?? 1.0
        let confidence = min(maxScore / 10.0, 1.0)

        var answerParts: [String] = []
        var allEndpoints: [EndpointInfo] = []
        var sources: [String] = []

        for item in topSections {
            let section = knowledgeBase[item.index]
            answerParts.append(section.content)
            allEndpoints.append(contentsOf: section.endpoints)
            sources.append(section.topic)
        }

        let answer = generateAnswer(question: question, contexts: answerParts, endpoints: allEndpoints)

        return RAGResponse(
            answer: answer,
            relevantEndpoints: allEndpoints,
            confidence: confidence,
            sources: sources
        )
    }

    // MARK: - Answer Generation

    private func generateAnswer(question: String, contexts: [String], endpoints: [EndpointInfo]) -> String {
        let questionLower = question.lowercased()
        var response = ""

        // Detect question intent
        if questionLower.contains("how") && (questionLower.contains("authenticate") || questionLower.contains("login") || questionLower.contains("connect")) {
            response = "To authenticate with Commvault SaaS:\n\n"
            response += "1. **API Key (Recommended)**: Create an access token via the Command Center or POST /ApiToken. Include it in the 'Authtoken' header for all requests.\n\n"
            response += "2. **Username/Password**: POST to /Login with credentials to receive a JWT token.\n\n"
            response += "Your SaaS endpoint follows the pattern: https://M{ring}.metallic.io/commandcenter/api/"
        } else if questionLower.contains("endpoint") || questionLower.contains("api") || questionLower.contains("url") {
            response = "Here are the relevant API endpoints:\n\n"
            for ep in endpoints.prefix(8) {
                response += "• **\(ep.method)** `\(ep.path)` - \(ep.description)\n"
            }
        } else if questionLower.contains("fail") || questionLower.contains("error") || questionLower.contains("issue") {
            response = contexts.first ?? ""
            if !endpoints.isEmpty {
                response += "\n\nUseful endpoints for troubleshooting:\n"
                let troubleshootEndpoints = endpoints.filter {
                    $0.path.contains("Fail") || $0.path.contains("Alert") || $0.path.contains("Job")
                }
                for ep in troubleshootEndpoints.prefix(5) {
                    response += "• **\(ep.method)** `\(ep.path)` - \(ep.description)\n"
                }
            }
        } else {
            // General knowledge response
            response = contexts.joined(separator: "\n\n")
            if !endpoints.isEmpty {
                response += "\n\n**Related API Endpoints:**\n"
                for ep in endpoints.prefix(6) {
                    response += "• **\(ep.method)** `\(ep.path)` - \(ep.description)\n"
                }
            }
        }

        return response
    }

    // MARK: - NLP Utilities

    private func tokenize(_ text: String) -> [String] {
        tokenizer.string = text
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range]).lowercased()
            if token.count > 1 { // Skip single characters
                tokens.append(token)
            }
            return true
        }
        return tokens
    }

    private func lemmatize(_ text: String) -> [String] {
        lemmatizer.string = text
        var lemmas: [String] = []
        lemmatizer.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma) { tag, range in
            if let lemma = tag?.rawValue.lowercased(), lemma.count > 1 {
                lemmas.append(lemma)
            }
            return true
        }
        return lemmas
    }

    // MARK: - Embedded Knowledge Fallback

    private func createEmbeddedKnowledgeJSON() -> String {
        // This provides a minimal embedded knowledge base as a fallback
        // when the JSON bundle resource is not found
        return """
        {
          "sections": [
            {
              "topic": "Authentication",
              "category": "core",
              "content": "Use API tokens or username/password to authenticate. Include token in Authtoken header. SaaS endpoints: https://M{ring}.metallic.io/commandcenter/api/",
              "endpoints": [
                {"method": "POST", "path": "/Login", "description": "Login with credentials"},
                {"method": "POST", "path": "/ApiToken", "description": "Create access token"},
                {"method": "GET", "path": "/ApiToken", "description": "List access tokens"}
              ],
              "keywords": ["login", "authenticate", "token", "api key"]
            },
            {
              "topic": "Dashboard & Health",
              "category": "monitoring",
              "content": "Monitor environment health via dashboard APIs. Health Overview shows Good/Info/Warning/Critical counts.",
              "endpoints": [
                {"method": "GET", "path": "/CommServ/CommCellInfo", "description": "CommCell details"},
                {"method": "GET", "path": "/DashboardTile/HealthOverview", "description": "Health overview"},
                {"method": "GET", "path": "/DashboardTile/SLA", "description": "SLA compliance"}
              ],
              "keywords": ["dashboard", "health", "sla", "status"]
            },
            {
              "topic": "Job Operations",
              "category": "core",
              "content": "Manage backup and restore jobs. Filter by status, client, and time range.",
              "endpoints": [
                {"method": "GET", "path": "/Job", "description": "List jobs"},
                {"method": "GET", "path": "/Job/{jobId}", "description": "Job details"},
                {"method": "POST", "path": "/Job/{jobId}/Action/Resubmit", "description": "Resubmit failed job"}
              ],
              "keywords": ["job", "backup", "restore", "failed"]
            },
            {
              "topic": "Alerts",
              "category": "monitoring",
              "content": "Get triggered alerts with severity levels: 1=Info, 2=Warning, 4=Critical.",
              "endpoints": [
                {"method": "GET", "path": "/AlertRule/Triggered", "description": "Get triggered alerts"},
                {"method": "GET", "path": "/AlertRule", "description": "List alert rules"}
              ],
              "keywords": ["alert", "notification", "warning", "critical"]
            },
            {
              "topic": "SaaS Usage",
              "category": "saas",
              "content": "SaaS-specific endpoints for subscription management. Ring-based URLs: M{nn}.metallic.io",
              "endpoints": [
                {"method": "GET", "path": "/Metallic/Usage/Summary", "description": "Tenant usage summary"},
                {"method": "GET", "path": "/Metallic/Usage/Details", "description": "Detailed usage"}
              ],
              "keywords": ["metallic", "saas", "usage", "subscription", "ring"]
            }
          ]
        }
        """
    }
}
