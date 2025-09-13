import Foundation

// MARK: - Remote LLM Provider (OpenAI-compatible)
final class RemoteLLMProvider: LLMProviderProtocol {
    static let shared = RemoteLLMProvider()
    private init() {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 90
        return URLSession(configuration: config)
    }()

    // Prefer Info.plist keys; allow UserDefaults override for quick testing
    private enum Keys {
        static let baseURL = "REMOTE_LLM_BASE_URL"
        static let apiKey = "REMOTE_LLM_API_KEY" // optional for self-hosted
        static let model = "REMOTE_LLM_MODEL"
    }

    private func cfg(_ key: String) -> String? {
        if let s = UserDefaults.standard.string(forKey: key), !s.isEmpty { return s }
        if let dict = Bundle.main.infoDictionary, let s = dict[key] as? String, !s.isEmpty { return s }
        return nil
    }

    private func endpoint() -> (URL, String?, String)? {
        guard let base = cfg(Keys.baseURL), let baseURL = URL(string: base), let model = cfg(Keys.model) else {
            return nil
        }
        return (baseURL.appendingPathComponent("v1/chat/completions"), cfg(Keys.apiKey), model)
    }

    struct ChatMessage: Codable { let role: String; let content: String }
    struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double?
        let max_tokens: Int?
        let stream: Bool?
    }
    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let role: String?; let content: String? }
            let index: Int?
            let message: Message?
        }
        let choices: [Choice]
    }

    func generateResponse(_ prompt: String) async throws -> String {
        // If not configured, fall back to local provider
        guard let (url, apiKey, model) = endpoint() else {
            return try await EnhancedLLMProvider.shared.generateResponse(prompt)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey, !apiKey.isEmpty {
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let system = "You are CalendAI, a helpful planning assistant. Be concise and actionable."
        let body = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: prompt)
            ],
            temperature: 0.6,
            max_tokens: 512,
            stream: false
        )
        req.httpBody = try JSONEncoder().encode(body)

        try Task.checkCancellation()
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let text = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "RemoteLLM", code: code, userInfo: [NSLocalizedDescriptionKey: "Remote error (\(code)): \(text)"])
        }

        try Task.checkCancellation()
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        if let content = decoded.choices.first?.message?.content, !content.isEmpty {
            return content
        }
        // Fallback if remote returned empty
        return try await EnhancedLLMProvider.shared.generateResponse(prompt)
    }

    func analyzeTask(_ taskDescription: String) async throws -> TaskAnalysis {
        // For now, rely on local heuristics until remote JSON modes are added
        return try await EnhancedLLMProvider.shared.analyzeTask(taskDescription)
    }

    func generateSmartSuggestions(_ context: String) async throws -> [SmartSuggestion] {
        return try await EnhancedLLMProvider.shared.generateSmartSuggestions(context)
    }

    func optimizeSchedule(_ tasks: [TaskSummary]) async throws -> ScheduleOptimization {
        return try await EnhancedLLMProvider.shared.optimizeSchedule(tasks)
    }

    func detectIntent(_ input: String) async throws -> UserIntent {
        return try await EnhancedLLMProvider.shared.detectIntent(input)
    }
}

