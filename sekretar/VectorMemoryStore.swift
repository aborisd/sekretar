import Foundation
import CoreData

// MARK: - Vector Memory Store (Week 1-2: Vector Memory System)

/// Локальное хранилище векторной памяти с semantic search
/// Использует CoreData для хранения векторов и метаданных
actor VectorMemoryStore {

    // MARK: - Singleton

    static let shared = VectorMemoryStore()

    // MARK: - Properties

    private let context: NSManagedObjectContext
    private let embedder: LocalEmbedder

    // MARK: - Initialization

    private init() {
        self.embedder = LocalEmbedder.shared
        self.context = PersistenceController.shared.container.newBackgroundContext()
        self.context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        print("📦 [VectorMemory] Initialized with CoreData")
    }

    // MARK: - Memory Operations

    /// Добавляет память в хранилище
    func addMemory(
        content: String,
        type: MemoryType,
        metadata: [String: Any]? = nil
    ) async throws {
        // Генерируем embedding
        let embeddingVector = try await embedder.embed(content)
        let embeddingData = encodeEmbedding(embeddingVector)

        // Сериализуем metadata
        var metadataJSON: String? = nil
        if let metadata = metadata {
            let jsonData = try JSONSerialization.data(withJSONObject: metadata)
            metadataJSON = String(data: jsonData, encoding: .utf8)
        }

        // Сохраняем в CoreData
        try await context.perform {
            // Создаем новую запись памяти через UserDefaults (временное решение)
            // TODO: Создать VectorMemory entity в CoreData model
            let memory = VectorMemoryEntry(
                content: content,
                type: type,
                embedding: embeddingData,
                metadata: metadataJSON,
                timestamp: Date()
            )

            // Сохраняем в UserDefaults как временное хранилище
            self.saveMemoryToUserDefaults(memory)

            print("💾 [VectorMemory] Added \(type.rawValue): \(content.prefix(50))...")
        }
    }

    /// Поиск похожих воспоминаний по semantic similarity
    func searchSimilar(
        query: String,
        limit: Int = 5,
        type: MemoryType? = nil,
        minSimilarity: Float = 0.5
    ) async throws -> [Memory] {
        // Генерируем embedding для запроса
        let queryEmbedding = try await embedder.embed(query)

        // Загружаем все memories из UserDefaults
        let allMemories = loadMemoriesFromUserDefaults()

        // Фильтруем по типу если указан
        var filteredMemories = allMemories
        if let type = type {
            filteredMemories = allMemories.filter { $0.type == type }
        }

        // Вычисляем similarity для каждой записи
        var similarities: [(Memory, Float)] = []

        for entry in filteredMemories.prefix(1000) {
            let memoryEmbedding = decodeEmbedding(entry.embedding)
            let similarity = cosineSimilarity(queryEmbedding, memoryEmbedding)

            if similarity >= minSimilarity {
                let memory = Memory(
                    id: entry.id,
                    content: entry.content,
                    type: entry.type,
                    timestamp: entry.timestamp,
                    metadata: parseMetadata(entry.metadata),
                    similarity: similarity
                )

                similarities.append((memory, similarity))
            }
        }

        // Сортируем по similarity и берем top N
        let topResults = similarities
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }

        print("🔍 [VectorMemory] Found \(topResults.count) similar memories for: \(query.prefix(30))...")

        return topResults
    }

    /// Получает последние N воспоминаний
    func getRecent(limit: Int = 10, type: MemoryType? = nil) async throws -> [Memory] {
        var memories = loadMemoriesFromUserDefaults()

        // Фильтруем по типу если указан
        if let type = type {
            memories = memories.filter { $0.type == type }
        }

        // Сортируем по timestamp
        memories.sort { $0.timestamp > $1.timestamp }

        // Берем top N
        return memories.prefix(limit).map { entry in
            Memory(
                id: entry.id,
                content: entry.content,
                type: entry.type,
                timestamp: entry.timestamp,
                metadata: parseMetadata(entry.metadata),
                similarity: 1.0
            )
        }
    }

    /// Удаляет старые воспоминания (для управления размером БД)
    func pruneOldMemories(olderThan days: Int = 90) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        var memories = loadMemoriesFromUserDefaults()
        let before = memories.count

        memories = memories.filter { $0.timestamp >= cutoffDate }

        saveMemoriesToUserDefaults(memories)

        let deleted = before - memories.count
        print("🗑️ [VectorMemory] Pruned \(deleted) old memories")
    }

    /// Очистка всей памяти (для тестирования)
    func clearAll() async throws {
        UserDefaults.standard.removeObject(forKey: "VectorMemoryStore")
        print("🗑️ [VectorMemory] Cleared all memories")
    }

    // MARK: - Helper Methods

    private func encodeEmbedding(_ embedding: [Float]) -> Data {
        return Data(bytes: embedding.flatMap { withUnsafeBytes(of: $0, Array.init) })
    }

    private func decodeEmbedding(_ data: Data) -> [Float] {
        return data.withUnsafeBytes { ptr in
            Array(ptr.bindMemory(to: Float.self))
        }
    }

    private func parseMetadata(_ json: String?) -> [String: Any]? {
        guard let json = json,
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }

    // MARK: - UserDefaults Persistence (Temporary)

    private func saveMemoryToUserDefaults(_ memory: VectorMemoryEntry) {
        var memories = loadMemoriesFromUserDefaults()
        memories.append(memory)
        saveMemoriesToUserDefaults(memories)
    }

    private func loadMemoriesFromUserDefaults() -> [VectorMemoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: "VectorMemoryStore"),
              let memories = try? JSONDecoder().decode([VectorMemoryEntry].self, from: data) else {
            return []
        }
        return memories
    }

    private func saveMemoriesToUserDefaults(_ memories: [VectorMemoryEntry]) {
        guard let data = try? JSONEncoder().encode(memories) else { return }
        UserDefaults.standard.set(data, forKey: "VectorMemoryStore")
    }

    // MARK: - Statistics

    func getStats() async throws -> MemoryStats {
        let memories = loadMemoriesFromUserDefaults()
        let total = memories.count

        var typeBreakdown: [String: Int] = [:]
        for type in MemoryType.allCases {
            let count = memories.filter { $0.type == type }.count
            typeBreakdown[type.rawValue] = count
        }

        let oldest = memories.min(by: { $0.timestamp < $1.timestamp })?.timestamp
        let newest = memories.max(by: { $0.timestamp < $1.timestamp })?.timestamp

        return MemoryStats(
            totalMemories: total,
            typeBreakdown: typeBreakdown,
            oldestMemory: oldest,
            newestMemory: newest
        )
    }
}

// MARK: - Data Models

/// Тип воспоминания
enum MemoryType: String, CaseIterable, Codable {
    case interaction    // Взаимодействие пользователь-AI
    case task           // Информация о задаче
    case event          // Информация о событии
    case insight        // AI insights/patterns
    case preference     // Пользовательские предпочтения
    case context        // Контекстная информация
}

/// Внутренняя структура для хранения в UserDefaults
struct VectorMemoryEntry: Codable {
    let id: Int64
    let content: String
    let type: MemoryType
    let embedding: Data
    let metadata: String?
    let timestamp: Date

    init(content: String, type: MemoryType, embedding: Data, metadata: String?, timestamp: Date) {
        self.id = Int64.random(in: 1...Int64.max)
        self.content = content
        self.type = type
        self.embedding = embedding
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

/// Структура воспоминания
struct Memory {
    let id: Int64
    let content: String
    let type: MemoryType
    let timestamp: Date
    let metadata: [String: Any]?
    let similarity: Float // Для результатов поиска
}

/// Статистика по памяти
struct MemoryStats {
    let totalMemories: Int
    let typeBreakdown: [String: Int]
    let oldestMemory: Date?
    let newestMemory: Date?

    var summary: String {
        return """
        📊 Vector Memory Statistics
        Total memories: \(totalMemories)
        Type breakdown:
        \(typeBreakdown.map { "  - \($0.key): \($0.value)" }.joined(separator: "\n"))
        Date range: \(oldestMemory?.formatted(date: .abbreviated, time: .omitted) ?? "N/A") - \(newestMemory?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")
        """
    }
}
