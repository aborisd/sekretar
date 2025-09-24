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

    // Prefer (1) UserDefaults, (2) RemoteLLM.plist (local, ignored by git), (3) Info.plist
    private enum Keys {
        static let baseURL = "REMOTE_LLM_BASE_URL"
        static let apiKey = "REMOTE_LLM_API_KEY" // optional for self-hosted
        static let model = "REMOTE_LLM_MODEL"
        static let maxTokens = "REMOTE_LLM_MAX_TOKENS"    // optional Int
        static let temperature = "REMOTE_LLM_TEMPERATURE" // optional Double
        static let httpReferer = "REMOTE_LLM_HTTP_REFERER" // optional, for OpenRouter etiquette
        static let httpTitle = "REMOTE_LLM_HTTP_TITLE"     // optional, for OpenRouter etiquette
    }

    private lazy var localPlist: [String: Any]? = {
        // Only allow local bundle plist overrides in debug builds to avoid shipping secrets
        #if DEBUG
        for name in ["RemoteLLM.local", "RemoteLLM"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "plist"),
               let data = try? Data(contentsOf: url),
               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                return plist
            }
        }
        #endif
        return nil
    }()

    private func cfg(_ key: String) -> String? {
        if let s = UserDefaults.standard.string(forKey: key), !s.isEmpty { return s }
        if let s = localPlist?[key] as? String, !s.isEmpty { return s }
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

    // Streaming chunk (OpenAI-compatible SSE data)
    struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { let content: String? }
            let delta: Delta
        }
        let choices: [Choice]
    }

    func generateResponse(_ prompt: String) async throws -> String {
        // If not configured, fall back to local provider
        guard let (url, apiKey, model) = endpoint() else {
            return try await EnhancedLLMProvider.shared.generateResponse(prompt)
        }

        // Try streaming first
        do {
            let result = try await streamingCompletion(url: url, apiKey: apiKey, model: model, userPrompt: prompt)
            if !result.isEmpty { return result }
        } catch is CancellationError { throw CancellationError() } catch {
            // fall back to non-streamed
        }

        // Non-streamed fallback
        let system = "You are Sekretar, a helpful planning assistant. Be concise and actionable."
        let temp = Double(cfg(Keys.temperature) ?? "") ?? 0.6
        let maxTok = Int(cfg(Keys.maxTokens) ?? "") ?? 384
        let body = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: prompt)
            ],
            temperature: temp,
            max_tokens: maxTok,
            stream: false
        )
        let data = try await postJSON(url: url, apiKey: apiKey, body: body)
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        if let content = decoded.choices.first?.message?.content, !content.isEmpty {
            return content
        }
        return try await EnhancedLLMProvider.shared.generateResponse(prompt)
    }

    // MARK: - JSON Modes (strict decode with retries)
    private func jsonCall<T: Decodable>(schemaDescription: String, userContent: String, type: T.Type) async throws -> T {
        guard let (url, apiKey, model) = endpoint() else { throw NSError(domain: "RemoteLLM", code: -2) }
        let temp = Double(cfg(Keys.temperature) ?? "") ?? 0.2
        let maxTok = Int(cfg(Keys.maxTokens) ?? "") ?? 384
        let system = "You are a strict JSON function. Return ONLY compact JSON matching the schema. No text. No code fences. If unsure, set empty strings/arrays and reasonable defaults. Schema: \n\(schemaDescription)"

        func attempt(promptSuffix: String?) async throws -> T {
            var messages: [ChatMessage] = [.init(role: "system", content: system), .init(role: "user", content: userContent)]
            if let s = promptSuffix { messages.append(.init(role: "system", content: s)) }
            let body = ChatRequest(model: model, messages: messages, temperature: temp, max_tokens: maxTok, stream: false)
            let data = try await postJSON(url: url, apiKey: apiKey, body: body)
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = decoded.choices.first?.message?.content else { throw NSError(domain: "RemoteLLM", code: -3) }
            guard let jsonData = content.data(using: .utf8) else { throw NSError(domain: "RemoteLLM", code: -4) }
            return try JSONDecoder().decode(T.self, from: jsonData)
        }

        do { return try await attempt(promptSuffix: nil) }
        catch {
            // Retry with explicit reminder
            return try await attempt(promptSuffix: "Reminder: respond with ONLY valid JSON per schema. No prose.")
        }
    }

    // MARK: - LLMProviderProtocol (JSON-backed)
    struct IntentJSON: Decodable { let intent: String }
    private func heuristicIntent(_ s: String) -> UserIntent? {
        let t = s.lowercased()
        func any(_ arr: [String]) -> Bool { arr.contains { t.contains($0) } }
        if (any(["создай","добавь","создать","добавить"]) && any(["задач","task"])) || any(["create","add","new task","i need to"]) { return .createTask }
        if any(["измени","обнови","переименуй","modify","change","update"]) { return .modifyTask }
        if any(["удали","удалить","remove","delete"]) { return .deleteTask }
        if any(["запланируй","подбери","найди","распиши","назначь"]) || any(["встреч","calendar","meeting","schedule"]) { return .scheduleTask }
        if any(["предложи","подскажи","порекомендуй","suggest","recommend"]) { return .requestSuggestion }
        return nil
    }
    func detectIntent(_ input: String) async throws -> UserIntent {
        // If not configured, use local
        guard endpoint() != nil else { return try await EnhancedLLMProvider.shared.detectIntent(input) }
        // Quick RU/EN heuristic first to avoid misclassification by remote
        if let h = heuristicIntent(input) { return h }
        // Remote JSON classification (language-agnostic instruction)
        let schema = "{" +
            "\"intent\": one of [create_task, modify_task, delete_task, schedule_task, ask_question, request_suggestion]" +
        "}"
        let prompt = "Classify the user intent from the following text (may be Russian or English). Return ONLY JSON with field 'intent'. Text: \n\(input)"
        do {
            let payload = try await jsonCall(schemaDescription: schema, userContent: prompt, type: IntentJSON.self)
            switch payload.intent {
            case "create_task": return .createTask
            case "modify_task": return .modifyTask
            case "delete_task": return .deleteTask
            case "schedule_task": return .scheduleTask
            case "ask_question": return .askQuestion
            case "request_suggestion": return .requestSuggestion
            default:
                return heuristicIntent(input) ?? .unknown
            }
        } catch {
            // Fallback to heuristic on any remote failure
            return heuristicIntent(input) ?? .unknown
        }
    }

    struct AnalysisJSON: Decodable {
        let suggested_priority: Int
        let estimated_duration_minutes: Int
        let suggested_tags: [String]
        let potential_subtasks: [String]?
        let category: String
        let complexity: String
    }
    func analyzeTask(_ taskDescription: String) async throws -> TaskAnalysis {
        guard endpoint() != nil else { return try await EnhancedLLMProvider.shared.analyzeTask(taskDescription) }
        let schema = "{" +
            "\"suggested_priority\": 0..3, " +
            "\"estimated_duration_minutes\": integer, " +
            "\"suggested_tags\": array[string], " +
            "\"potential_subtasks\": array[string], " +
            "\"category\": string, " +
            "\"complexity\": one of [simple, moderate, complex, expert]" +
        "}"
        let json = try await jsonCall(schemaDescription: schema, userContent: "Analyze task: \(taskDescription)", type: AnalysisJSON.self)
        let complexity: TaskComplexity = {
            switch json.complexity.lowercased() {
            case "simple": return .simple
            case "moderate": return .moderate
            case "complex": return .complex
            case "expert": return .expert
            default: return .simple
            }
        }()
        return TaskAnalysis(
            suggestedPriority: max(0, min(3, json.suggested_priority)),
            estimatedDuration: TimeInterval(json.estimated_duration_minutes * 60),
            suggestedTags: json.suggested_tags,
            potentialSubtasks: json.potential_subtasks ?? [],
            category: json.category,
            complexity: complexity
        )
    }

    func generateSmartSuggestions(_ context: String) async throws -> [SmartSuggestion] {
        // Keep local heuristics for now
        return try await EnhancedLLMProvider.shared.generateSmartSuggestions(context)
    }

    struct RemoteTaskInput: Codable {
        let id: String
        let title: String
        let priority: Int
        let due_iso: String?
        let estimated_minutes: Int
        let is_completed: Bool
    }
    struct OptimizationJSON: Decodable {
        struct Item: Decodable {
            let task_id: String
            let suggested_start_iso: String
            let suggested_duration_minutes: Int
            let confidence: Double
        }
        let reasoning: String
        let productivity_score: Double
        let items: [Item]
    }
    func optimizeSchedule(_ tasks: [TaskSummary]) async throws -> ScheduleOptimization {
        guard endpoint() != nil else { return try await EnhancedLLMProvider.shared.optimizeSchedule(tasks) }
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let inputs = tasks.map { t in
            RemoteTaskInput(
                id: t.id.uuidString,
                title: t.title,
                priority: t.priority,
                due_iso: t.dueDate.map { df.string(from: $0) },
                estimated_minutes: Int(t.estimatedDuration / 60),
                is_completed: t.isCompleted
            )
        }
        let tasksJSONData = try JSONEncoder().encode(inputs)
        let tasksJSONString = String(data: tasksJSONData, encoding: .utf8) ?? "[]"
        let tz = TimeZone.current.identifier
        let schema = "{" +
            "\"reasoning\": string, " +
            "\"productivity_score\": number, " +
            "\"items\": array[{task_id:string, suggested_start_iso:ISO8601, suggested_duration_minutes:int, confidence:number}]" +
        "}"
        let prompt = "Given tasks (JSON array) and timezone, propose a next-day schedule. Use only free working hours 09:00-18:00, add 15m buffers, avoid past due. Tasks: \n\(tasksJSONString)\nTimezone: \(tz). Return strictly JSON per schema."
        let json = try await jsonCall(schemaDescription: schema, userContent: prompt, type: OptimizationJSON.self)
        let optimized = json.items.compactMap { item -> OptimizedTask? in
            guard let start = df.date(from: item.suggested_start_iso), let id = UUID(uuidString: item.task_id) else { return nil }
            return OptimizedTask(taskId: id, suggestedStartTime: start, suggestedDuration: TimeInterval(item.suggested_duration_minutes * 60), confidence: max(0.1, min(1.0, item.confidence)))
        }
        return ScheduleOptimization(
            optimizedTasks: optimized,
            reasoning: json.reasoning,
            productivityScore: json.productivity_score,
            suggestions: []
        )
    }

    // MARK: - HTTP helpers
    private func postJSON<T: Encodable>(url: URL, apiKey: String?, body: T) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey, !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        if let referer = cfg(Keys.httpReferer) { req.setValue(referer, forHTTPHeaderField: "HTTP-Referer") }
        if let title = cfg(Keys.httpTitle) { req.setValue(title, forHTTPHeaderField: "X-Title") }
        req.httpBody = try JSONEncoder().encode(body)
        try Task.checkCancellation()
        let (data, response) = try await session.data(for: req)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let text = String(data: data, encoding: .utf8) ?? ""
            let friendly: String
            switch code {
            case 401, 403: friendly = "Ошибка авторизации: проверьте API ключ."
            case 429: friendly = "Слишком много запросов: подождите немного и повторите."
            default: friendly = "Удалённая ошибка (\(code))."
            }
            throw NSError(domain: "RemoteLLM", code: code, userInfo: [NSLocalizedDescriptionKey: friendly + "\n" + text])
        }
        return data
    }

    private func streamingCompletion(url: URL, apiKey: String?, model: String, userPrompt: String) async throws -> String {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let apiKey, !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        if let referer = cfg(Keys.httpReferer) { req.setValue(referer, forHTTPHeaderField: "HTTP-Referer") }
        if let title = cfg(Keys.httpTitle) { req.setValue(title, forHTTPHeaderField: "X-Title") }

        let system = "You are Sekretar, a helpful planning assistant. Be concise and actionable."
        let temp = Double(cfg(Keys.temperature) ?? "") ?? 0.6
        let maxTok = Int(cfg(Keys.maxTokens) ?? "") ?? 384
        let body = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: userPrompt)
            ],
            temperature: temp,
            max_tokens: maxTok,
            stream: true
        )
        req.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            // fall back to non-stream
            return ""
        }
        var text = ""
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let jsonLine = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if jsonLine == "[DONE]" { break }
            if let data = jsonLine.data(using: .utf8), let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data) {
                if let delta = chunk.choices.first?.delta.content { text += delta }
            }
        }
        return text
    }

    // Event parsing via JSON schema
    struct EventJSON: Decodable {
        let title: String
        let start_iso: String
        let end_iso: String
        let all_day: Bool?
    }

    func parseEvent(_ description: String) async throws -> EventDraft {
        guard endpoint() != nil else { return try await EnhancedLLMProvider.shared.parseEvent(description) }
        let schema = "{" +
            "\"title\": string, \"start_iso\": ISO8601, \"end_iso\": ISO8601, \"all_day\": boolean" +
        "}"
        let json = try await jsonCall(schemaDescription: schema, userContent: "Parse event from text: \(description)", type: EventJSON.self)
        let df = ISO8601DateFormatter(); df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let start = df.date(from: json.start_iso) ?? Date()
        let end = df.date(from: json.end_iso) ?? start.addingTimeInterval(3600)
        return EventDraft(title: json.title, start: start, end: end, isAllDay: json.all_day ?? false)
    }

    // (Legacy fallbacks removed — handled above per-method)
}
