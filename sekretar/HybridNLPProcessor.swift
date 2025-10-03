import Foundation

// MARK: - Hybrid NLP System (из ai_calendar_production_plan_v4.md)

/// Hybrid NLP Processor - комбинирует локальную CoreML модель с облачным fallback
/// Решает проблему keyword-based парсинга из MVP
class HybridNLPProcessor {

    // MARK: - Components

    private let localNLU: LocalNLUModel
    private let cloudNLU: CloudNLUService
    private let contextParser: ContextAwareParser
    private let spellingCorrector: SpellingCorrector

    // MARK: - Configuration

    private let confidenceThreshold: Double = 0.85
    private let maxCloudRetries = 2

    init() {
        self.localNLU = LocalNLUModel()
        self.cloudNLU = CloudNLUService()
        self.contextParser = ContextAwareParser()
        self.spellingCorrector = SpellingCorrector()
    }

    // MARK: - Main Processing

    func processInput(_ text: String) async throws -> ParsedIntent {
        // Шаг 1: Исправление опечаток (Levenshtein distance)
        let correctedText = spellingCorrector.correct(text)

        // Шаг 2: Проверка на составные команды
        if let compoundCommands = try await parseCompoundCommands(correctedText) {
            return compoundCommands
        }

        // Шаг 3: Быстрая локальная обработка
        let localResult = try await localNLU.parse(correctedText)

        // Шаг 4: Оценка уверенности
        if localResult.confidence > confidenceThreshold {
            return localResult
        }

        // Шаг 5: Облачная обработка для сложных случаев
        let context = contextParser.getCurrentContext()
        let cloudResult = try await cloudNLU.parse(
            correctedText,
            withContext: context,
            retries: maxCloudRetries
        )

        // Шаг 6: Обучение локальной модели на успешных результатах
        await localNLU.learn(from: cloudResult)

        return cloudResult
    }

    // MARK: - Compound Commands Parsing

    /// Парсинг составных команд: "создай задачу X завтра и напомни за час"
    private func parseCompoundCommands(_ text: String) async throws -> ParsedIntent? {
        // Паттерны для составных команд
        let compoundPatterns = [
            // "создай задачу X и напомни..."
            #"создай задачу (.+?) (?:и|а также|плюс) напомни (.+)"#,
            // "купить A, B, and C"
            #"(?:купи(?:ть)?|создай задач[иу]) (.+?,\s*.+)"#,
            // "завтра встреча и послезавтра звонок"
            #"(.+?) и (.+)"#
        ]

        for patternStr in compoundPatterns {
            guard let regex = try? NSRegularExpression(pattern: patternStr, options: .caseInsensitive) else {
                continue
            }

            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                return try await parseMultipleCommands(from: match, in: text)
            }
        }

        return nil
    }

    private func parseMultipleCommands(from match: NSTextCheckingResult, in text: String) async throws -> ParsedIntent {
        var commands: [SingleIntent] = []

        for i in 1..<match.numberOfRanges {
            guard let range = Range(match.range(at: i), in: text) else { continue }
            let commandText = String(text[range])

            // Рекурсивно парсим каждую команду
            let intent = try await processInput(commandText)
            if case .multiple(let intents) = intent {
                commands.append(contentsOf: intents)
            } else if case .single(let singleIntent) = intent {
                commands.append(singleIntent)
            }
        }

        return .multiple(commands)
    }
}

// MARK: - Local NLU Model (CoreML Stub)

/// Локальная NLU модель (CoreML)
/// TODO: Интегрировать реальную CoreML модель в Week 1-2
class LocalNLUModel {

    private var learnedPatterns: [String: ParsedIntent] = [:]

    func parse(_ text: String) async throws -> ParsedIntent {
        // Пока используем улучшенный keyword-based подход
        // В Week 1-2 заменим на CoreML модель

        let lowercased = text.lowercased()

        // Проверка контекстных ссылок
        if lowercased.contains("как в прошлый раз") || lowercased.contains("like last time") {
            return try await handleContextualReference(text)
        }

        // Базовый keyword парсинг с улучшениями
        return try keywordBasedParse(text)
    }

    func learn(from result: ParsedIntent) async {
        // Сохраняем успешные паттерны для будущего использования
        // Упрощенная версия online learning
        if result.confidence > 0.9 {
            learnedPatterns[result.originalText.lowercased()] = result
        }
    }

    private func handleContextualReference(_ text: String) async throws -> ParsedIntent {
        // TODO: Интегрировать с VectorMemoryStore для поиска предыдущих действий
        // Сейчас возвращаем placeholder
        return ParsedIntent(
            type: .contextualReference,
            confidence: 0.7,
            originalText: text,
            referenceText: "прошлый раз"
        )
    }

    private func keywordBasedParse(_ text: String) throws -> ParsedIntent {
        let lowercased = text.lowercased()

        // Определение типа действия
        if lowercased.contains("создай задачу") || lowercased.contains("create task") {
            return ParsedIntent(
                type: .createTask,
                confidence: 0.85,
                originalText: text,
                extractedData: extractTaskData(from: text)
            )
        }

        if lowercased.contains("создай событие") || lowercased.contains("create event") {
            return ParsedIntent(
                type: .createEvent,
                confidence: 0.85,
                originalText: text,
                extractedData: extractEventData(from: text)
            )
        }

        // Низкая уверенность - нужен cloud fallback
        return ParsedIntent(
            type: .unknown,
            confidence: 0.4,
            originalText: text
        )
    }

    private func extractTaskData(from text: String) -> [String: Any] {
        // Используем существующий NaturalLanguageDateParser
        let parser = NaturalLanguageDateParser()

        var data: [String: Any] = [:]

        // Извлекаем дату/время
        if let dateResult = parser.parse(text, reference: Date()) {
            data["dueDate"] = dateResult.start
        }

        // Извлекаем приоритет
        if text.lowercased().contains("важн") || text.lowercased().contains("high") {
            data["priority"] = 3
        } else if text.lowercased().contains("средн") || text.lowercased().contains("medium") {
            data["priority"] = 2
        }

        return data
    }

    private func extractEventData(from text: String) -> [String: Any] {
        let parser = NaturalLanguageDateParser()
        var data: [String: Any] = [:]

        if let dateResult = parser.parse(text, reference: Date()) {
            data["startDate"] = dateResult.start
            data["endDate"] = dateResult.end
            data["isAllDay"] = dateResult.isAllDay
        }

        return data
    }
}

// MARK: - Cloud NLU Service

/// Cloud NLU Service - fallback для сложных запросов
class CloudNLUService {

    private let llmClient: MultiProviderLLMClient

    init() {
        // Интегрируется со SmartLLMRouter через MultiProviderLLMClient
        self.llmClient = MultiProviderLLMClient.shared
    }

    func parse(_ text: String, withContext context: UserContext, retries: Int) async throws -> ParsedIntent {
        // Используем SmartRouter для парсинга через LLM
        let prompt = buildNLUPrompt(text: text, context: context)

        do {
            let response = try await llmClient.generateWithRouting(prompt, userTier: .free)

            // Парсим ответ от LLM
            return try parseNLUResponse(response, originalText: text)

        } catch {
            print("⚠️ [CloudNLU] Failed to parse via LLM: \(error)")

            // Fallback на базовый парсинг
            return ParsedIntent(
                type: .unknown,
                confidence: 0.3,
                originalText: text,
                cloudProcessed: false
            )
        }
    }

    private func buildNLUPrompt(text: String, context: UserContext) -> String {
        return """
        Parse the following user request into a structured intent.

        User request: \(text)

        Context:
        - Current time: \(context.timeContext)
        - Recent tasks: \(context.recentTasks.count)
        - Recent events: \(context.recentEvents.count)

        Respond with JSON:
        {
            "intent_type": "create_task|create_event|update_task|update_event|delete_task|delete_event|unknown",
            "confidence": 0.0-1.0,
            "extracted_data": {
                "title": "string (optional)",
                "due_date": "ISO8601 (optional)",
                "priority": 1-3 (optional),
                "is_all_day": boolean (optional)
            }
        }
        """
    }

    struct NLUResponseJSON: Decodable {
        let intent_type: String
        let confidence: Double
        let extracted_data: ExtractedData?

        struct ExtractedData: Decodable {
            let title: String?
            let due_date: String?
            let priority: Int?
            let is_all_day: Bool?
        }
    }

    private func parseNLUResponse(_ response: String, originalText: String) throws -> ParsedIntent {
        // Парсим JSON ответ от LLM
        guard let jsonData = response.data(using: .utf8) else {
            throw NSError(domain: "CloudNLU", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to encode response"])
        }

        let decoded = try JSONDecoder().decode(NLUResponseJSON.self, from: jsonData)

        // Преобразуем в IntentType
        let intentType: IntentType = {
            switch decoded.intent_type {
            case "create_task": return .createTask
            case "create_event": return .createEvent
            case "update_task": return .updateTask
            case "update_event": return .updateEvent
            case "delete_task": return .deleteTask
            case "delete_event": return .deleteEvent
            default: return .unknown
            }
        }()

        // Собираем extracted data
        var extractedData: [String: Any] = [:]
        if let data = decoded.extracted_data {
            if let title = data.title {
                extractedData["title"] = title
            }
            if let dueDate = data.due_date, let date = ISO8601DateFormatter().date(from: dueDate) {
                extractedData["dueDate"] = date
            }
            if let priority = data.priority {
                extractedData["priority"] = priority
            }
            if let isAllDay = data.is_all_day {
                extractedData["isAllDay"] = isAllDay
            }
        }

        return ParsedIntent(
            type: intentType,
            confidence: decoded.confidence,
            originalText: originalText,
            extractedData: extractedData,
            cloudProcessed: true
        )
    }
}

// MARK: - Context Aware Parser

/// Контекстный парсер - помнит историю и предпочтения пользователя
class ContextAwareParser {

    func getCurrentContext() -> UserContext {
        // TODO: Интегрировать с VectorMemoryStore в Week 1-2
        return UserContext(
            recentTasks: [],
            recentEvents: [],
            userPreferences: [:],
            timeContext: Date()
        )
    }
}

// MARK: - Spelling Corrector

/// Исправление опечаток с помощью Levenshtein distance
class SpellingCorrector {

    private let commonWords: Set<String> = [
        "создай", "создать", "задачу", "задача", "событие", "завтра",
        "сегодня", "напомни", "напоминание", "встреча", "купить",
        "create", "task", "event", "tomorrow", "today", "reminder"
    ]

    private let maxDistance = 2 // Максимальная дистанция для коррекции

    func correct(_ text: String) -> String {
        let words = text.split(separator: " ")
        var correctedWords: [String] = []

        for word in words {
            let wordStr = String(word)

            // Проверяем, нужна ли коррекция
            if commonWords.contains(wordStr.lowercased()) {
                correctedWords.append(wordStr)
                continue
            }

            // Ищем ближайшее правильное слово
            if let corrected = findClosestWord(wordStr) {
                correctedWords.append(corrected)
            } else {
                correctedWords.append(wordStr)
            }
        }

        return correctedWords.joined(separator: " ")
    }

    private func findClosestWord(_ word: String) -> String? {
        let lowercased = word.lowercased()
        var bestMatch: String?
        var bestDistance = Int.max

        for commonWord in commonWords {
            let distance = levenshteinDistance(lowercased, commonWord)
            if distance <= maxDistance && distance < bestDistance {
                bestDistance = distance
                bestMatch = commonWord
            }
        }

        return bestMatch
    }

    // Levenshtein distance algorithm
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m {
            matrix[i][0] = i
        }

        for j in 0...n {
            matrix[0][j] = j
        }

        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[m][n]
    }
}

// MARK: - Data Models

enum ParsedIntent {
    case single(SingleIntent)
    case multiple([SingleIntent])
    case contextualReference
    case unknown

    var confidence: Double {
        switch self {
        case .single(let intent):
            return intent.confidence
        case .multiple(let intents):
            return intents.map { $0.confidence }.reduce(0, +) / Double(intents.count)
        case .contextualReference:
            return 0.7
        case .unknown:
            return 0.0
        }
    }

    var originalText: String {
        switch self {
        case .single(let intent):
            return intent.originalText
        case .multiple(let intents):
            return intents.map { $0.originalText }.joined(separator: " и ")
        case .contextualReference:
            return ""
        case .unknown:
            return ""
        }
    }

    init(type: IntentType, confidence: Double, originalText: String, extractedData: [String: Any] = [:], cloudProcessed: Bool = false, referenceText: String? = nil) {
        self = .single(SingleIntent(
            type: type,
            confidence: confidence,
            originalText: originalText,
            extractedData: extractedData,
            cloudProcessed: cloudProcessed
        ))
    }
}

struct SingleIntent {
    let type: IntentType
    let confidence: Double
    let originalText: String
    let extractedData: [String: Any]
    let cloudProcessed: Bool

    init(type: IntentType, confidence: Double, originalText: String, extractedData: [String: Any] = [:], cloudProcessed: Bool = false) {
        self.type = type
        self.confidence = confidence
        self.originalText = originalText
        self.extractedData = extractedData
        self.cloudProcessed = cloudProcessed
    }
}

enum IntentType {
    case createTask
    case createEvent
    case updateTask
    case updateEvent
    case deleteTask
    case deleteEvent
    case contextualReference
    case unknown
}

struct UserContext {
    let recentTasks: [Any] // TODO: Типизировать когда будет Task model
    let recentEvents: [Any]
    let userPreferences: [String: Any]
    let timeContext: Date
}
