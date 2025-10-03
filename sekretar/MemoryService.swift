import Foundation
import CoreData

// MARK: - Memory Service (Week 1-2: Vector Memory Integration)

/// Сервис для управления долговременной памятью AI
/// Автоматически сохраняет взаимодействия и обогащает контекст
@MainActor
class MemoryService {

    // MARK: - Singleton

    static let shared = MemoryService()

    // MARK: - Properties

    private let vectorStore: VectorMemoryStore
    private let context: NSManagedObjectContext?

    // MARK: - Initialization

    private init() {
        self.vectorStore = VectorMemoryStore.shared
        self.context = PersistenceController.shared.container.viewContext

        print("🧠 [MemoryService] Initialized")
    }

    // MARK: - Recording Interactions

    /// Записывает взаимодействие пользователя с AI
    func recordInteraction(
        userInput: String,
        aiResponse: String,
        intent: String? = nil
    ) async {
        let content = """
        User: \(userInput)
        AI: \(aiResponse)
        """

        var metadata: [String: Any] = [
            "user_input": userInput,
            "ai_response": aiResponse,
            "timestamp": Date().timeIntervalSince1970
        ]

        if let intent = intent {
            metadata["intent"] = intent
        }

        do {
            try await vectorStore.addMemory(
                content: content,
                type: .interaction,
                metadata: metadata
            )
        } catch {
            print("⚠️ [MemoryService] Failed to record interaction: \(error)")
        }
    }

    /// Записывает создание/изменение задачи
    func recordTaskAction(_ task: TaskEntity, action: TaskAction) async {
        guard let title = task.title else { return }

        let content: String
        switch action {
        case .created:
            content = "Создана задача: \(title)"
        case .completed:
            content = "Выполнена задача: \(title)"
        case .updated:
            content = "Обновлена задача: \(title)"
        case .deleted:
            content = "Удалена задача: \(title)"
        }

        var metadata: [String: Any] = [
            "task_id": task.id?.uuidString ?? "",
            "task_title": title,
            "action": action.rawValue,
            "priority": task.priority,
            "timestamp": Date().timeIntervalSince1970
        ]

        if let notes = task.notes {
            metadata["notes"] = notes
        }

        if let dueDate = task.dueDate {
            metadata["due_date"] = dueDate.timeIntervalSince1970
        }

        do {
            try await vectorStore.addMemory(
                content: content,
                type: .task,
                metadata: metadata
            )
        } catch {
            print("⚠️ [MemoryService] Failed to record task action: \(error)")
        }
    }

    /// Записывает создание/изменение события
    func recordEventAction(_ event: EventEntity, action: EventAction) async {
        guard let title = event.title else { return }

        let content: String
        switch action {
        case .created:
            content = "Создано событие: \(title)"
        case .updated:
            content = "Обновлено событие: \(title)"
        case .deleted:
            content = "Удалено событие: \(title)"
        }

        var metadata: [String: Any] = [
            "event_id": event.id?.uuidString ?? "",
            "event_title": title,
            "action": action.rawValue,
            "is_all_day": event.isAllDay,
            "timestamp": Date().timeIntervalSince1970
        ]

        if let notes = event.notes {
            metadata["notes"] = notes
        }

        if let startDate = event.startDate {
            metadata["start_date"] = startDate.timeIntervalSince1970
        }

        if let endDate = event.endDate {
            metadata["end_date"] = endDate.timeIntervalSince1970
        }

        do {
            try await vectorStore.addMemory(
                content: content,
                type: .event,
                metadata: metadata
            )
        } catch {
            print("⚠️ [MemoryService] Failed to record event action: \(error)")
        }
    }

    /// Сохраняет AI insight (паттерны, наблюдения)
    func recordInsight(_ insight: String, category: String? = nil) async {
        var metadata: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970
        ]

        if let category = category {
            metadata["category"] = category
        }

        do {
            try await vectorStore.addMemory(
                content: insight,
                type: .insight,
                metadata: metadata
            )

            print("💡 [MemoryService] Recorded insight: \(insight.prefix(50))...")
        } catch {
            print("⚠️ [MemoryService] Failed to record insight: \(error)")
        }
    }

    /// Сохраняет пользовательское предпочтение
    func recordPreference(key: String, value: String, description: String? = nil) async {
        let content = description ?? "\(key): \(value)"

        let metadata: [String: Any] = [
            "preference_key": key,
            "preference_value": value,
            "timestamp": Date().timeIntervalSince1970
        ]

        do {
            try await vectorStore.addMemory(
                content: content,
                type: .preference,
                metadata: metadata
            )
        } catch {
            print("⚠️ [MemoryService] Failed to record preference: \(error)")
        }
    }

    // MARK: - Retrieving Context

    /// Получает релевантный контекст для AI запроса
    func getRelevantContext(
        for query: String,
        limit: Int = 5,
        types: [MemoryType]? = nil
    ) async throws -> [Memory] {
        if let types = types {
            // Собираем воспоминания по каждому типу
            var allMemories: [Memory] = []

            for type in types {
                let memories = try await vectorStore.searchSimilar(
                    query: query,
                    limit: limit,
                    type: type,
                    minSimilarity: 0.6
                )
                allMemories.append(contentsOf: memories)
            }

            // Сортируем по similarity и берем top N
            return Array(allMemories
                .sorted { $0.similarity > $1.similarity }
                .prefix(limit))

        } else {
            // Ищем по всем типам
            return try await vectorStore.searchSimilar(
                query: query,
                limit: limit,
                minSimilarity: 0.6
            )
        }
    }

    /// Получает последние взаимодействия
    func getRecentInteractions(limit: Int = 10) async throws -> [Memory] {
        return try await vectorStore.getRecent(limit: limit, type: .interaction)
    }

    /// Получает контекст по конкретной задаче
    func getTaskContext(_ taskId: UUID) async throws -> [Memory] {
        let query = "task_id:\(taskId.uuidString)"
        return try await vectorStore.searchSimilar(
            query: query,
            limit: 10,
            type: .task,
            minSimilarity: 0.3
        )
    }

    /// Получает контекст по конкретному событию
    func getEventContext(_ eventId: UUID) async throws -> [Memory] {
        let query = "event_id:\(eventId.uuidString)"
        return try await vectorStore.searchSimilar(
            query: query,
            limit: 10,
            type: .event,
            minSimilarity: 0.3
        )
    }

    // MARK: - Context Building for AI

    /// Строит контекстный prompt для AI на основе релевантных воспоминаний
    func buildContextPrompt(for query: String, limit: Int = 5) async throws -> String {
        let relevantMemories = try await getRelevantContext(for: query, limit: limit)

        if relevantMemories.isEmpty {
            return ""
        }

        var contextPrompt = "\n\nRelevant context from memory:\n"

        for (index, memory) in relevantMemories.enumerated() {
            let timeAgo = formatTimeAgo(memory.timestamp)
            contextPrompt += "\n[\(index + 1)] (\(timeAgo), \(memory.type.rawValue)):\n"
            contextPrompt += memory.content.prefix(200)
            contextPrompt += "\n"
        }

        return contextPrompt
    }

    /// Форматирует "time ago" для удобочитаемости
    private func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }

    // MARK: - Maintenance

    /// Очистка старых воспоминаний
    func pruneOldMemories(olderThan days: Int = 90) async throws {
        try await vectorStore.pruneOldMemories(olderThan: days)
    }

    /// Статистика по памяти
    func getStats() async throws -> MemoryStats {
        return try await vectorStore.getStats()
    }

    /// Экспорт памяти для backup
    func exportMemories() async throws -> Data {
        let recentMemories = try await vectorStore.getRecent(limit: 1000)

        let exportData = recentMemories.map { memory in
            return [
                "content": memory.content,
                "type": memory.type.rawValue,
                "timestamp": memory.timestamp.timeIntervalSince1970,
                "metadata": memory.metadata ?? [:]
            ] as [String: Any]
        }

        return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }

    // MARK: - Auto Learning

    /// Анализирует паттерны и сохраняет insights
    func analyzePatterns() async {
        // TODO: Реализовать в Week 11-12 (Context Agent)
        // Анализирует поведение пользователя и находит паттерны:
        // - Время наибольшей продуктивности
        // - Часто откладываемые задачи
        // - Типичная длительность задач
        // - Предпочтения по расписанию
        print("🔍 [MemoryService] Pattern analysis not yet implemented")
    }
}

// MARK: - Enums

enum TaskAction: String {
    case created
    case completed
    case updated
    case deleted
}

enum EventAction: String {
    case created
    case updated
    case deleted
}
