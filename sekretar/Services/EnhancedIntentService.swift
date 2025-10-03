import Foundation
import NaturalLanguage

// MARK: - Enhanced Intent Service (Week 9-10: Advanced NLP)

/// Продвинутый сервис распознавания intent с entity extraction
actor EnhancedIntentService {

    static let shared = EnhancedIntentService()

    private let dateParser: DateParser
    private let entityExtractor: EntityExtractor
    private let contextManager: ConversationContextManager

    private init() {
        self.dateParser = DateParser()
        self.entityExtractor = EntityExtractor()
        self.contextManager = ConversationContextManager()
    }

    // MARK: - Intent Recognition

    /// Распознает intent с учетом контекста беседы
    func recognizeIntent(
        _ input: String,
        context: ConversationContext? = nil
    ) async throws -> RecognizedIntent {
        // Сохраняем в контекст
        if let context = context {
            await contextManager.addUserMessage(input, context: context)
        }

        // Извлекаем entities
        let entities = await entityExtractor.extract(from: input)

        // Распознаем базовый intent
        let baseIntent = classifyIntent(input, entities: entities)

        // Обогащаем контекстом
        let enrichedIntent = await enrichWithContext(baseIntent, context: context)

        return enrichedIntent
    }

    // MARK: - Intent Classification

    private func classifyIntent(_ input: String, entities: [Entity]) -> RecognizedIntent {
        let lowercased = input.lowercased()

        // Проверяем entity-based patterns
        if entities.contains(where: { $0.type == .date }) {
            if containsTaskKeywords(lowercased) {
                return RecognizedIntent(
                    type: .createTask,
                    confidence: 0.9,
                    entities: entities,
                    rawInput: input
                )
            } else if containsEventKeywords(lowercased) {
                return RecognizedIntent(
                    type: .createEvent,
                    confidence: 0.9,
                    entities: entities,
                    rawInput: input
                )
            }
        }

        // Fallback to keyword-based classification
        if containsTaskKeywords(lowercased) {
            return RecognizedIntent(
                type: .createTask,
                confidence: 0.7,
                entities: entities,
                rawInput: input
            )
        } else if containsEventKeywords(lowercased) {
            return RecognizedIntent(
                type: .createEvent,
                confidence: 0.7,
                entities: entities,
                rawInput: input
            )
        } else if containsSearchKeywords(lowercased) {
            return RecognizedIntent(
                type: .search,
                confidence: 0.8,
                entities: entities,
                rawInput: input
            )
        } else {
            return RecognizedIntent(
                type: .unknown,
                confidence: 0.3,
                entities: entities,
                rawInput: input
            )
        }
    }

    // MARK: - Context Enrichment

    private func enrichWithContext(
        _ intent: RecognizedIntent,
        context: ConversationContext?
    ) async -> RecognizedIntent {
        guard let context = context else {
            return intent
        }

        // Если intent неясен, пытаемся понять из контекста
        if intent.type == .unknown {
            let contextualIntent = await contextManager.inferIntent(from: context)
            if let contextualIntent = contextualIntent {
                return RecognizedIntent(
                    type: contextualIntent,
                    confidence: 0.6,
                    entities: intent.entities,
                    rawInput: intent.rawInput,
                    contextualInfo: "Inferred from conversation context"
                )
            }
        }

        // Дополняем entities из контекста
        let contextualEntities = await contextManager.extractMissingEntities(
            for: intent,
            from: context
        )

        return RecognizedIntent(
            type: intent.type,
            confidence: intent.confidence,
            entities: intent.entities + contextualEntities,
            rawInput: intent.rawInput,
            contextualInfo: contextualEntities.isEmpty ? nil : "Enriched with context"
        )
    }

    // MARK: - Helper Methods

    private func containsTaskKeywords(_ text: String) -> Bool {
        let taskKeywords = [
            // English
            "task", "todo", "reminder", "remember", "don't forget",
            "need to", "have to", "must", "should",
            // Russian
            "задача", "задачу", "напомни", "напомнить", "не забыть",
            "нужно", "надо", "должен", "должна"
        ]
        return taskKeywords.contains { text.contains($0) }
    }

    private func containsEventKeywords(_ text: String) -> Bool {
        let eventKeywords = [
            // English
            "meeting", "event", "appointment", "schedule", "calendar",
            "book", "reserve", "plan",
            // Russian
            "встреча", "встречу", "событие", "мероприятие", "запланировать",
            "забронировать", "назначить", "календарь"
        ]
        return eventKeywords.contains { text.contains($0) }
    }

    private func containsSearchKeywords(_ text: String) -> Bool {
        let searchKeywords = [
            // English
            "find", "search", "show", "list", "what", "when", "where",
            // Russian
            "найти", "найди", "покажи", "показать", "список", "что", "когда", "где"
        ]
        return searchKeywords.contains { text.contains($0) }
    }
}

// MARK: - Date Parser

/// Парсер дат с поддержкой natural language
actor DateParser {

    /// Извлекает даты из текста
    func extractDates(from text: String) async -> [ExtractedDate] {
        var dates: [ExtractedDate] = []

        // Относительные даты
        dates += extractRelativeDates(from: text)

        // Абсолютные даты
        dates += extractAbsoluteDates(from: text)

        // Времена
        dates += extractTimes(from: text)

        return dates
    }

    private func extractRelativeDates(from text: String) -> [ExtractedDate] {
        let lowercased = text.lowercased()
        var dates: [ExtractedDate] = []

        let today = Calendar.current.startOfDay(for: Date())

        // English relative dates
        if lowercased.contains("today") || lowercased.contains("сегодня") {
            dates.append(ExtractedDate(
                date: today,
                type: .relative,
                matchedText: "today/сегодня",
                confidence: 0.95
            ))
        }

        if lowercased.contains("tomorrow") || lowercased.contains("завтра") {
            if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) {
                dates.append(ExtractedDate(
                    date: tomorrow,
                    type: .relative,
                    matchedText: "tomorrow/завтра",
                    confidence: 0.95
                ))
            }
        }

        if lowercased.contains("next week") || lowercased.contains("следующая неделя") || lowercased.contains("на следующей неделе") {
            if let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: today) {
                dates.append(ExtractedDate(
                    date: nextWeek,
                    type: .relative,
                    matchedText: "next week",
                    confidence: 0.9
                ))
            }
        }

        // Day names
        let weekdays = [
            ("monday", "понедельник", 2),
            ("tuesday", "вторник", 3),
            ("wednesday", "среда", 4),
            ("thursday", "четверг", 5),
            ("friday", "пятница", 6),
            ("saturday", "суббота", 7),
            ("sunday", "воскресенье", 1)
        ]

        for (en, ru, weekday) in weekdays {
            if lowercased.contains(en) || lowercased.contains(ru) {
                if let date = nextDateFor(weekday: weekday, from: today) {
                    dates.append(ExtractedDate(
                        date: date,
                        type: .relative,
                        matchedText: "\(en)/\(ru)",
                        confidence: 0.85
                    ))
                }
            }
        }

        return dates
    }

    private func extractAbsoluteDates(from text: String) -> [ExtractedDate] {
        var dates: [ExtractedDate] = []

        // Patterns: "15 января", "January 15", "15.01.2024", etc.
        let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = dataDetector?.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches ?? [] {
            if let date = match.date {
                let matchedText = (text as NSString).substring(with: match.range)
                dates.append(ExtractedDate(
                    date: date,
                    type: .absolute,
                    matchedText: matchedText,
                    confidence: 0.9
                ))
            }
        }

        return dates
    }

    private func extractTimes(from text: String) -> [ExtractedDate] {
        var dates: [ExtractedDate] = []

        // Patterns: "в 15:00", "at 3pm", "в 3 часа", etc.
        let timeRegex = try? NSRegularExpression(
            pattern: #"(\d{1,2}):?(\d{2})?\s*(am|pm|AM|PM)?|в\s+(\d{1,2})\s+час"#
        )

        let matches = timeRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches ?? [] {
            let matchedText = (text as NSString).substring(with: match.range)
            if let time = parseTime(matchedText) {
                dates.append(ExtractedDate(
                    date: time,
                    type: .time,
                    matchedText: matchedText,
                    confidence: 0.85
                ))
            }
        }

        return dates
    }

    private func nextDateFor(weekday: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)

        var daysToAdd = weekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: date)
    }

    private func parseTime(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        // Try parsing as HH:mm
        if let time = formatter.date(from: text) {
            return time
        }

        // Try extracting hour from text like "в 3 часа"
        let regex = try? NSRegularExpression(pattern: #"(\d{1,2})"#)
        if let match = regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let hourString = (text as NSString).substring(with: match.range)
            if let hour = Int(hourString) {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = hour
                components.minute = 0
                return Calendar.current.date(from: components)
            }
        }

        return nil
    }
}

// MARK: - Entity Extractor

/// Извлекает entities (даты, места, людей) из текста
actor EntityExtractor {

    private let tagger: NLTagger

    init() {
        self.tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    }

    func extract(from text: String) async -> [Entity] {
        var entities: [Entity] = []

        // Extract dates
        let dateParser = DateParser()
        let dates = await dateParser.extractDates(from: text)
        entities += dates.map { Entity(type: .date, value: $0.date, matchedText: $0.matchedText, confidence: $0.confidence) }

        // Extract locations, people, organizations using NLTagger
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            guard let tag = tag else { return true }

            let matchedText = String(text[range])

            switch tag {
            case .personalName:
                entities.append(Entity(type: .person, value: matchedText, matchedText: matchedText, confidence: 0.8))
            case .placeName:
                entities.append(Entity(type: .location, value: matchedText, matchedText: matchedText, confidence: 0.8))
            case .organizationName:
                entities.append(Entity(type: .organization, value: matchedText, matchedText: matchedText, confidence: 0.75))
            default:
                break
            }

            return true
        }

        return entities
    }
}

// MARK: - Conversation Context Manager

/// Управляет контекстом беседы для multi-turn conversations
actor ConversationContextManager {

    private var contexts: [UUID: ConversationHistory] = [:]

    func addUserMessage(_ message: String, context: ConversationContext) async {
        var history = contexts[context.conversationId] ?? ConversationHistory()
        history.messages.append(ConversationMessage(
            role: .user,
            content: message,
            timestamp: Date()
        ))
        contexts[context.conversationId] = history
    }

    func inferIntent(from context: ConversationContext) async -> EnhancedIntentType? {
        guard let history = contexts[context.conversationId],
              let lastAssistantMessage = history.messages.last(where: { $0.role == .assistant }) else {
            return nil
        }

        // Simple heuristic: if last message was asking about task creation, assume follow-up is task-related
        if lastAssistantMessage.content.lowercased().contains("task") ||
           lastAssistantMessage.content.lowercased().contains("задач") {
            return .createTask
        }

        if lastAssistantMessage.content.lowercased().contains("event") ||
           lastAssistantMessage.content.lowercased().contains("встреч") {
            return .createEvent
        }

        return nil
    }

    func extractMissingEntities(for intent: RecognizedIntent, from context: ConversationContext) async -> [Entity] {
        guard let history = contexts[context.conversationId] else {
            return []
        }

        var missingEntities: [Entity] = []

        // If current intent lacks date but previous messages mentioned dates, reuse them
        let hasDate = intent.entities.contains { $0.type == .date }
        if !hasDate {
            for message in history.messages.reversed().prefix(3) {
                let extractor = EntityExtractor()
                let entities = await extractor.extract(from: message.content)
                if let dateEntity = entities.first(where: { $0.type == .date }) {
                    missingEntities.append(dateEntity)
                    break
                }
            }
        }

        return missingEntities
    }
}

// MARK: - Data Models

enum EnhancedIntentType: String, Codable {
    case createTask
    case createEvent
    case search
    case update
    case delete
    case unknown
}

struct RecognizedIntent {
    let type: EnhancedIntentType
    let confidence: Double
    let entities: [Entity]
    let rawInput: String
    var contextualInfo: String?
}

enum ExtractedEntityType {
    case date
    case time
    case location
    case person
    case organization
    case duration
}

struct Entity {
    let type: ExtractedEntityType
    let value: Any
    let matchedText: String
    let confidence: Double
}

struct ExtractedDate {
    let date: Date
    let type: DateType
    let matchedText: String
    let confidence: Double

    enum DateType {
        case absolute
        case relative
        case time
    }
}

struct ConversationContext {
    let conversationId: UUID
    let userId: String?
}

struct ConversationHistory {
    var messages: [ConversationMessage] = []
}

struct ConversationMessage {
    let role: MessageRole
    let content: String
    let timestamp: Date

    enum MessageRole {
        case user
        case assistant
    }
}
