import Foundation

// MARK: - Multi-Provider LLM Client with Smart Routing
/// Интегрирует SmartLLMRouter с существующими провайдерами (RemoteLLMProvider)
/// Автоматически выбирает оптимальную модель на основе сложности запроса
@MainActor
final class MultiProviderLLMClient {

    static let shared = MultiProviderLLMClient()

    private let router: SmartLLMRouterService
    private let session: URLSession
    private let responseValidator: AIResponseValidator

    // MARK: - Configuration Keys (using RemoteLLMProvider convention)

    private enum Keys {
        // Gemini Flash
        static let geminiBaseURL = "GEMINI_BASE_URL"
        static let geminiAPIKey = "GEMINI_API_KEY"

        // OpenAI GPT-4o-mini
        static let openaiBaseURL = "OPENAI_BASE_URL"
        static let openaiAPIKey = "OPENAI_API_KEY"

        // Anthropic Claude Sonnet
        static let anthropicBaseURL = "ANTHROPIC_BASE_URL"
        static let anthropicAPIKey = "ANTHROPIC_API_KEY"

        // Fallback to generic remote config
        static let remoteBaseURL = "REMOTE_LLM_BASE_URL"
        static let remoteAPIKey = "REMOTE_LLM_API_KEY"
    }

    private init() {
        self.router = SmartLLMRouterService()
        self.responseValidator = AIResponseValidator()

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 90
        self.session = URLSession(configuration: config)

        // Подключаем реальную генерацию к router'у
        router.setGenerateFunction { [weak self] model, request in
            guard let self = self else {
                throw NSError(domain: "MultiProviderClient", code: -99,
                             userInfo: [NSLocalizedDescriptionKey: "Client deallocated"])
            }
            return try await self.realGenerate(model: model, request: request)
        }

        print("🌐 [MultiProviderClient] Initialized with smart routing + validation")
    }

    /// Реальная генерация для router'а
    private func realGenerate(model: LLMModel, request: LLMRequest) async throws -> LLMResponse {
        let startTime = Date()

        guard let (url, apiKey, modelName) = endpoint(for: model) else {
            throw NSError(domain: "MultiProviderClient", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Model \(model.rawValue) not configured"])
        }

        let system = "You are Sekretar, a helpful planning assistant. Be concise and actionable."

        let body = ChatRequest(
            model: modelName,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: request.input)
            ],
            temperature: 0.6,
            max_tokens: 384,
            stream: false
        )

        let data = try await postJSON(url: url, apiKey: apiKey, body: body)
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)

        guard let content = decoded.choices.first?.message?.content, !content.isEmpty else {
            throw NSError(domain: "MultiProviderClient", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Empty response from \(model.rawValue)"])
        }

        let latency = Date().timeIntervalSince(startTime)

        // Примерная оценка токенов (для метрик)
        let inputTokens = request.input.split(separator: " ").count * 2
        let outputTokens = content.split(separator: " ").count * 2

        return LLMResponse(
            content: content,
            modelUsed: model,
            tokensUsed: TokenUsage(input: inputTokens, output: outputTokens),
            latencyMs: latency * 1000,
            cached: false
        )
    }

    // MARK: - Configuration Resolution

    private lazy var localPlist: [String: Any]? = {
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

    /// Получить endpoint для конкретной модели
    private func endpoint(for model: LLMModel) -> (URL, String?, String)? {
        switch model {
        case .geminiFlash:
            guard let base = cfg(Keys.geminiBaseURL) ?? cfg(Keys.remoteBaseURL),
                  let url = URL(string: base) else { return nil }
            return (
                url.appendingPathComponent("v1/chat/completions"),
                cfg(Keys.geminiAPIKey) ?? cfg(Keys.remoteAPIKey),
                "gemini-1.5-flash"
            )

        case .gpt4oMini:
            guard let base = cfg(Keys.openaiBaseURL) ?? cfg(Keys.remoteBaseURL),
                  let url = URL(string: base) else { return nil }
            return (
                url.appendingPathComponent("v1/chat/completions"),
                cfg(Keys.openaiAPIKey) ?? cfg(Keys.remoteAPIKey),
                "gpt-4o-mini"
            )

        case .claudeSonnet:
            guard let base = cfg(Keys.anthropicBaseURL) ?? cfg(Keys.remoteBaseURL),
                  let url = URL(string: base) else { return nil }
            return (
                url.appendingPathComponent("v1/chat/completions"),
                cfg(Keys.anthropicAPIKey) ?? cfg(Keys.remoteAPIKey),
                "claude-sonnet-4.5"
            )
        }
    }

    // MARK: - Smart Routing API

    /// Генерация с автоматическим выбором модели
    func generateWithRouting(
        _ prompt: String,
        userTier: SubscriptionTier = .free
    ) async throws -> String {

        let request = LLMRequest(input: prompt, userTier: userTier)

        // Router автоматически выберет модель и закэширует результат
        let response = try await router.route(request)

        return response.content
    }

    /// Генерация с валидацией ответа (для структурированных данных)
    func generateWithValidation(
        _ prompt: String,
        userTier: SubscriptionTier = .free,
        validationContext: ValidationContext
    ) async throws -> ValidatedResponse {

        let request = LLMRequest(input: prompt, userTier: userTier)
        let llmResponse = try await router.route(request)

        // Преобразуем LLMResponse в AIResponse для валидации
        let aiResponse = try parseAIResponse(from: llmResponse.content)

        // Валидируем ответ
        let validated = try await responseValidator.validateAndImprove(
            response: aiResponse,
            context: validationContext
        )

        return validated
    }

    /// Парсинг LLM ответа в AIResponse
    private func parseAIResponse(from content: String) throws -> AIResponse {
        // Пытаемся распарсить как JSON
        guard let jsonData = content.data(using: .utf8) else {
            throw NSError(domain: "MultiProviderClient", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to encode response"])
        }

        do {
            let decoded = try JSONDecoder().decode(AIResponseJSON.self, from: jsonData)

            return AIResponse(
                action: decoded.action,
                extractedData: decoded.extracted_data ?? [:],
                confidence: decoded.confidence ?? 0.8,
                metadata: [:]
            )
        } catch {
            // Fallback: если не JSON, возвращаем базовый AIResponse
            return AIResponse(
                action: nil,
                extractedData: ["raw_content": content],
                confidence: 0.5,
                metadata: ["parse_error": error.localizedDescription]
            )
        }
    }

    struct AIResponseJSON: Decodable {
        let action: String?
        let extracted_data: [String: Any]?
        let confidence: Double?

        private enum CodingKeys: String, CodingKey {
            case action
            case extracted_data
            case confidence
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            action = try container.decodeIfPresent(String.self, forKey: .action)
            confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)

            // Декодируем extracted_data как generic dictionary
            if let dataContainer = try? container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .extracted_data) {
                var data: [String: Any] = [:]
                for key in dataContainer.allKeys {
                    if let value = try? dataContainer.decode(String.self, forKey: key) {
                        data[key.stringValue] = value
                    } else if let value = try? dataContainer.decode(Int.self, forKey: key) {
                        data[key.stringValue] = value
                    } else if let value = try? dataContainer.decode(Double.self, forKey: key) {
                        data[key.stringValue] = value
                    } else if let value = try? dataContainer.decode(Bool.self, forKey: key) {
                        data[key.stringValue] = value
                    }
                }
                extracted_data = data
            } else {
                extracted_data = nil
            }
        }
    }

    struct AnyCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }

    /// Генерация с явной моделью (bypass routing)
    func generate(
        _ prompt: String,
        model: LLMModel,
        temperature: Double = 0.6,
        maxTokens: Int = 384
    ) async throws -> String {

        guard let (url, apiKey, modelName) = endpoint(for: model) else {
            throw NSError(domain: "MultiProviderClient", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Model \(model.rawValue) not configured"])
        }

        let system = "You are Sekretar, a helpful planning assistant. Be concise and actionable."

        let body = ChatRequest(
            model: modelName,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: prompt)
            ],
            temperature: temperature,
            max_tokens: maxTokens,
            stream: false
        )

        let data = try await postJSON(url: url, apiKey: apiKey, body: body)
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)

        guard let content = decoded.choices.first?.message?.content, !content.isEmpty else {
            throw NSError(domain: "MultiProviderClient", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Empty response from \(model.rawValue)"])
        }

        return content
    }

    // MARK: - JSON Mode with Routing

    /// JSON вызов с smart routing
    func jsonCallWithRouting<T: Decodable>(
        schemaDescription: String,
        userContent: String,
        type: T.Type,
        userTier: SubscriptionTier = .free
    ) async throws -> T {

        // Создаем полный prompt для классификации сложности
        let fullPrompt = "JSON Schema: \(schemaDescription)\nUser Content: \(userContent)"
        let request = LLMRequest(input: fullPrompt, userTier: userTier)

        // Router выбирает модель
        let response = try await router.route(request)

        // Парсим JSON
        guard let jsonData = response.content.data(using: .utf8) else {
            throw NSError(domain: "MultiProviderClient", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to encode response as UTF-8"])
        }

        return try JSONDecoder().decode(T.self, from: jsonData)
    }

    // MARK: - Analytics & Management

    /// Получить статистику router'а
    func getRouterStats() -> RouterStats {
        return router.getStats()
    }

    /// Очистить кэш
    func clearCache() async {
        await router.clearCache()
    }

    // MARK: - HTTP Helpers (from RemoteLLMProvider)

    struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double?
        let max_tokens: Int?
        let stream: Bool?
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let role: String?
                let content: String?
            }
            let index: Int?
            let message: Message?
        }
        let choices: [Choice]
    }

    private func postJSON<T: Encodable>(url: URL, apiKey: String?, body: T) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if let apiKey, !apiKey.isEmpty {
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        req.httpBody = try JSONEncoder().encode(body)

        try Task.checkCancellation()

        let (data, response) = try await session.data(for: req)

        try Task.checkCancellation()

        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let text = String(data: data, encoding: .utf8) ?? ""

            let friendly: String
            switch code {
            case 401, 403:
                friendly = "Ошибка авторизации: проверьте API ключ."
            case 429:
                friendly = "Слишком много запросов: подождите немного и повторите."
            default:
                friendly = "Удалённая ошибка (\(code))."
            }

            throw NSError(domain: "MultiProviderClient", code: code,
                         userInfo: [NSLocalizedDescriptionKey: friendly + "\n" + text])
        }

        return data
    }
}

// MARK: - LLMProviderProtocol Adapter
/// Адаптер для совместимости с существующим LLMProviderProtocol
extension MultiProviderLLMClient: LLMProviderProtocol {

    func generateResponse(_ prompt: String) async throws -> String {
        return try await generateWithRouting(prompt, userTier: .free)
    }

    func detectIntent(_ input: String) async throws -> UserIntent {
        // Используем RemoteLLMProvider для intent detection
        return try await RemoteLLMProvider.shared.detectIntent(input)
    }

    func analyzeTask(_ taskDescription: String) async throws -> TaskAnalysis {
        // Используем RemoteLLMProvider для task analysis
        return try await RemoteLLMProvider.shared.analyzeTask(taskDescription)
    }

    func generateSmartSuggestions(_ context: String) async throws -> [SmartSuggestion] {
        // Используем RemoteLLMProvider для suggestions
        return try await RemoteLLMProvider.shared.generateSmartSuggestions(context)
    }

    func optimizeSchedule(_ tasks: [TaskSummary]) async throws -> ScheduleOptimization {
        // Используем RemoteLLMProvider для schedule optimization
        return try await RemoteLLMProvider.shared.optimizeSchedule(tasks)
    }

    func parseEvent(_ description: String) async throws -> EventDraft {
        // Используем RemoteLLMProvider для event parsing
        return try await RemoteLLMProvider.shared.parseEvent(description)
    }
}
