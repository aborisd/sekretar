import Foundation
import CryptoKit

// MARK: - Smart LLM Router (из ai_calendar_production_plan.md Week 3-4)

/// Интеллектуальный роутер LLM запросов для оптимизации costs (60-70% экономия)
/// Автоматически выбирает оптимальную модель на основе сложности запроса
@MainActor
class SmartLLMRouterService {

    // MARK: - Properties

    private let classifier: ComplexityClassifier
    private let cache: LLMCache
    private let analytics: RouterAnalytics

    // Callback для реальной генерации (инжектируется извне)
    private var generateFunc: ((LLMModel, LLMRequest) async throws -> LLMResponse)?

    // MARK: - Initialization

    init() {
        self.classifier = ComplexityClassifier()
        self.cache = LLMCache()
        self.analytics = RouterAnalytics()

        print("🧠 [SmartRouter] Initialized with intelligent routing")
    }

    /// Установить функцию для реальной генерации
    func setGenerateFunction(_ generate: @escaping (LLMModel, LLMRequest) async throws -> LLMResponse) {
        self.generateFunc = generate
        print("🔗 [SmartRouter] Connected to real LLM provider")
    }

    // MARK: - Main Routing

    /// Роутинг запроса к оптимальной LLM с кэшированием
    func route(_ request: LLMRequest) async throws -> LLMResponse {
        let startTime = Date()

        // 1. Проверяем cache first
        let cacheKey = generateCacheKey(request)
        if let cached = await cache.get(cacheKey) {
            analytics.recordCacheHit(model: cached.modelUsed)
            print("💾 [SmartRouter] Cache HIT for: \(request.input.prefix(50))...")

            return cached
        }

        print("🔍 [SmartRouter] Cache MISS, routing to LLM...")

        // 2. Классифицируем сложность
        let classification = classifier.classifyDetailed(request.input)
        print("  Complexity: \(classification.complexity.description)")
        print("  Confidence: \(String(format: "%.1f%%", classification.confidence * 100))")

        // 3. Выбираем модель на основе сложности + user tier
        let selectedModel = selectModel(
            complexity: classification.complexity,
            userTier: request.userTier
        )

        print("  Selected model: \(selectedModel)")

        // 4. Генерируем ответ с retry logic
        let response: LLMResponse
        if let generate = generateFunc {
            // Используем реальную генерацию
            response = try await generateWithRetry(
                model: selectedModel,
                request: request,
                maxRetries: 2,
                generate: generate
            )
        } else {
            // Fallback на mock если не подключена реальная генерация
            response = try await mockGenerate(model: selectedModel, request: request)
        }

        // 5. Кэшируем результат
        let ttl = cacheTTL(for: classification.complexity)
        await cache.set(cacheKey, response, ttl: ttl)

        // 6. Записываем аналитику
        let latency = Date().timeIntervalSince(startTime)
        analytics.recordRequest(
            complexity: classification.complexity,
            model: selectedModel,
            userTier: request.userTier,
            latencyMs: latency * 1000,
            cachedResponse: false,
            success: true
        )

        return response
    }

    // MARK: - Model Selection

    /// Выбор оптимальной модели на основе сложности и user tier
    private func selectModel(
        complexity: Complexity,
        userTier: SubscriptionTier
    ) -> LLMModel {

        switch (complexity, userTier) {
        // Simple queries - всегда используем Gemini Flash (cheapest)
        case (.simple, _):
            return .geminiFlash

        // Medium queries
        case (.medium, .free), (.medium, .basic):
            return .geminiFlash  // Экономим для free/basic users
        case (.medium, .pro), (.medium, .premium), (.medium, .teams):
            return .gpt4oMini   // Лучше качество для платных

        // Complex queries
        case (.complex, .free), (.complex, .basic):
            return .gpt4oMini   // Fallback для free users
        case (.complex, .pro), (.complex, .premium), (.complex, .teams):
            return .claudeSonnet  // Premium для сложных задач
        }
    }

    // MARK: - Generation with Retry

    /// Генерация с retry logic и fallback
    private func generateWithRetry(
        model: LLMModel,
        request: LLMRequest,
        maxRetries: Int,
        generate: (LLMModel, LLMRequest) async throws -> LLMResponse
    ) async throws -> LLMResponse {

        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                let response = try await generate(model, request)

                if attempt > 0 {
                    print("  ✅ Retry successful on attempt \(attempt + 1)")
                }

                return response

            } catch let error as RateLimitError {
                lastError = error
                print("  ⚠️ Rate limit hit, attempt \(attempt + 1)/\(maxRetries + 1)")

                if attempt < maxRetries {
                    // Exponential backoff
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(for: .seconds(delay))
                } else {
                    // Last attempt - try fallback model
                    print("  🔄 Switching to fallback model...")
                    return try await generateWithFallback(model: model, request: request, generate: generate)
                }
            } catch {
                lastError = error
                throw error
            }
        }

        throw lastError ?? LLMError.maxRetriesExceeded
    }

    /// Fallback на более дешевую модель при проблемах
    private func generateWithFallback(
        model: LLMModel,
        request: LLMRequest,
        generate: (LLMModel, LLMRequest) async throws -> LLMResponse
    ) async throws -> LLMResponse {

        let fallbackModel: LLMModel = {
            switch model {
            case .claudeSonnet:
                return .gpt4oMini
            case .gpt4oMini:
                return .geminiFlash
            case .geminiFlash:
                return .geminiFlash // Can't fallback further
            }
        }()

        print("  📉 Using fallback: \(fallbackModel)")
        return try await generate(fallbackModel, request)
    }

    // MARK: - Cache Management

    /// Генерация cache key из запроса
    private func generateCacheKey(_ request: LLMRequest) -> String {
        // Используем SHA256 для стабильного хэша
        let data = Data(request.input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// TTL для кэша на основе сложности
    private func cacheTTL(for complexity: Complexity) -> TimeInterval {
        switch complexity {
        case .simple:
            return 3600    // 1 час для простых запросов
        case .medium:
            return 1800    // 30 минут для средних
        case .complex:
            return 600     // 10 минут для сложных
        }
    }

    // MARK: - Analytics

    /// Получить статистику роутера
    func getStats() -> RouterStats {
        return analytics.getStats()
    }

    /// Сбросить кэш
    func clearCache() async {
        await cache.clear()
        print("🗑️ [SmartRouter] Cache cleared")
    }

    // MARK: - Mock Generation (TODO: Remove в Week 3-4)

    private func mockGenerate(
        model: LLMModel,
        request: LLMRequest
    ) async throws -> LLMResponse {
        // Симулируем задержку в зависимости от модели
        let delay: TimeInterval = {
            switch model {
            case .geminiFlash: return 0.1
            case .gpt4oMini: return 0.3
            case .claudeSonnet: return 0.5
            }
        }()

        try await Task.sleep(for: .seconds(delay))

        // Mock response
        return LLMResponse(
            content: "Mock response from \(model.rawValue)",
            modelUsed: model,
            tokensUsed: TokenUsage(input: 100, output: 50),
            latencyMs: delay * 1000,
            cached: false
        )
    }
}

// MARK: - LLM Cache

/// Actor для thread-safe кэширования
actor LLMCache {
    private var storage: [String: CachedResponse] = [:]
    private var accessCount: [String: Int] = [:] // Для LRU

    struct CachedResponse {
        let response: LLMResponse
        let expiry: Date
    }

    func get(_ key: String) -> LLMResponse? {
        // Удаляем expired
        if let cached = storage[key] {
            if cached.expiry > Date() {
                accessCount[key, default: 0] += 1
                return cached.response
            } else {
                storage.removeValue(forKey: key)
                accessCount.removeValue(forKey: key)
            }
        }
        return nil
    }

    func set(_ key: String, _ response: LLMResponse, ttl: TimeInterval) {
        let expiry = Date().addingTimeInterval(ttl)
        storage[key] = CachedResponse(response: response, expiry: expiry)
        accessCount[key] = 0

        // LRU eviction если слишком большой
        if storage.count > 1000 {
            evictLRU()
        }
    }

    func clear() {
        storage.removeAll()
        accessCount.removeAll()
    }

    private func evictLRU() {
        // Удаляем 20% наименее используемых
        let toRemove = Int(Double(storage.count) * 0.2)
        let sorted = accessCount.sorted { $0.value < $1.value }

        for (key, _) in sorted.prefix(toRemove) {
            storage.removeValue(forKey: key)
            accessCount.removeValue(forKey: key)
        }
    }
}

// MARK: - Analytics

class RouterAnalytics {
    private var requestCount: [LLMModel: Int] = [:]
    private var cacheHits: [LLMModel: Int] = [:]
    private var totalLatency: [LLMModel: Double] = [:]
    private var costSavings: Double = 0

    func recordRequest(
        complexity: Complexity,
        model: LLMModel,
        userTier: SubscriptionTier,
        latencyMs: Double,
        cachedResponse: Bool,
        success: Bool
    ) {
        if cachedResponse {
            cacheHits[model, default: 0] += 1
        } else {
            requestCount[model, default: 0] += 1
            totalLatency[model, default: 0] += latencyMs
        }

        // Вычисляем экономию если использовали дешевую модель вместо дорогой
        if model == .geminiFlash && complexity == .complex {
            let savedCost = complexity.estimatedCostPer1KTokens.input - model.costPer1KTokens.input
            costSavings += savedCost
        }
    }

    func recordCacheHit(model: LLMModel) {
        cacheHits[model, default: 0] += 1
    }

    func getStats() -> RouterStats {
        let totalRequests = requestCount.values.reduce(0, +)
        let totalCacheHits = cacheHits.values.reduce(0, +)
        let cacheHitRate = totalRequests > 0 ? Double(totalCacheHits) / Double(totalRequests + totalCacheHits) : 0

        return RouterStats(
            totalRequests: totalRequests,
            cacheHits: totalCacheHits,
            cacheHitRate: cacheHitRate,
            modelUsage: requestCount,
            averageLatency: calculateAverageLatency(),
            estimatedCostSavings: costSavings
        )
    }

    private func calculateAverageLatency() -> [LLMModel: Double] {
        var avg: [LLMModel: Double] = [:]
        for (model, total) in totalLatency {
            let count = requestCount[model] ?? 1
            avg[model] = total / Double(count)
        }
        return avg
    }
}

// MARK: - Data Models

enum LLMModel: String, Codable {
    case geminiFlash = "gemini-1.5-flash"
    case gpt4oMini = "gpt-4o-mini"
    case claudeSonnet = "claude-sonnet-4.5"

    var costPer1KTokens: (input: Double, output: Double) {
        switch self {
        case .geminiFlash:
            return (0.075, 0.30)
        case .gpt4oMini:
            return (0.15, 0.60)
        case .claudeSonnet:
            return (3.0, 15.0)
        }
    }
}

// Note: SubscriptionTier is now defined in AuthManager.swift

struct LLMRequest {
    let input: String
    let userTier: SubscriptionTier
    let context: [String: Any]

    init(input: String, userTier: SubscriptionTier = .free, context: [String: Any] = [:]) {
        self.input = input
        self.userTier = userTier
        self.context = context
    }
}

struct LLMResponse {
    let content: String
    let modelUsed: LLMModel
    let tokensUsed: TokenUsage
    let latencyMs: Double
    let cached: Bool
}

struct TokenUsage {
    let input: Int
    let output: Int

    var total: Int {
        return input + output
    }
}

struct RouterStats {
    let totalRequests: Int
    let cacheHits: Int
    let cacheHitRate: Double
    let modelUsage: [LLMModel: Int]
    let averageLatency: [LLMModel: Double]
    let estimatedCostSavings: Double

    var summary: String {
        return """
        📊 Smart Router Statistics
        Total Requests: \(totalRequests)
        Cache Hits: \(cacheHits) (\(String(format: "%.1f%%", cacheHitRate * 100)))
        Model Usage:
        \(modelUsage.map { "  - \($0.key.rawValue): \($0.value)" }.joined(separator: "\n"))
        Estimated Savings: $\(String(format: "%.2f", estimatedCostSavings))
        """
    }
}

// MARK: - Errors

struct RateLimitError: Error {
    let retryAfter: TimeInterval
}

enum LLMError: Error {
    case maxRetriesExceeded
    case allModelsFailed
    case invalidResponse
}
