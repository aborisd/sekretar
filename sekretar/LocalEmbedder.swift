import Foundation
import CoreML
import NaturalLanguage

// MARK: - Local Embedder (из ai_calendar_production_plan.md Week 1-2)

/// On-device генерация embeddings для semantic search
/// Использует CoreML модель (Universal Sentence Encoder или аналог)
class LocalEmbedder {

    // MARK: - Singleton

    static let shared = LocalEmbedder()

    // MARK: - Properties

    private let maxLength = 512 // Token limit
    private let embeddingDimension = 768

    // TODO: Load real CoreML model in Week 1-2
    // private let model: MLModel?

    private init() {
        // Попытка загрузить CoreML модель
        // TODO: Добавить реальную модель из Apple/HuggingFace
        /*
        guard let modelURL = Bundle.main.url(forResource: "SentenceEncoder", withExtension: "mlmodelc"),
              let model = try? MLModel(contentsOf: modelURL) else {
            print("⚠️ [LocalEmbedder] CoreML model not found, using fallback")
            self.model = nil
            return
        }
        self.model = model
        */

        print("📦 [LocalEmbedder] Initialized")
    }

    // MARK: - Embedding Generation

    /// Генерирует embedding вектор для текста
    func embed(_ text: String) async throws -> [Float] {
        // TODO: В Week 1-2 заменить на реальную CoreML модель

        // Пока используем простой word-based подход для тестирования
        return generateSimpleEmbedding(text)

        /*
        // Real implementation (Week 1-2):
        guard let model = model else {
            // Fallback на простой подход
            return generateSimpleEmbedding(text)
        }

        // Tokenize
        let tokens = tokenize(text)

        // Prepare input
        let inputArray = try MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32)
        for (i, token) in tokens.enumerated() {
            inputArray[i] = NSNumber(value: token)
        }

        // Run model
        let input = SentenceEncoderInput(tokens: inputArray)
        let output = try model.prediction(from: input)

        // Extract embedding
        guard let embedding = output.featureValue(for: "embedding")?.multiArrayValue else {
            throw EmbeddingError.invalidOutput
        }

        // Convert to Float array
        return (0..<embedding.count).map { Float(truncating: embedding[$0]) }
        */
    }

    // MARK: - Simple Embedding (Fallback)

    /// Простой embedding на основе TF-IDF и word vectors
    /// Используется как fallback до интеграции CoreML модели
    private func generateSimpleEmbedding(_ text: String) -> [Float] {
        var embedding = [Float](repeating: 0.0, count: embeddingDimension)

        // Используем NLEmbedding от Apple (встроенный)
        if let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english) {
            // Получаем вектор для всего предложения
            if let vector = sentenceEmbedding.vector(for: text) {
                // NLEmbedding возвращает вектор меньшей размерности
                // Расширяем до 768 dimensions с padding
                for (index, value) in vector.enumerated() {
                    if index < embeddingDimension {
                        embedding[index] = Float(value)
                    }
                }
            }
        } else {
            // Ultimate fallback: хэш-based подход
            embedding = hashBasedEmbedding(text)
        }

        // Нормализуем вектор
        return normalizeVector(embedding)
    }

    /// Hash-based embedding как последний fallback
    private func hashBasedEmbedding(_ text: String) -> [Float] {
        var embedding = [Float](repeating: 0.0, count: embeddingDimension)

        // Разбиваем на слова
        let words = text.lowercased().split(separator: " ")

        for word in words {
            let hash = abs(word.hashValue)
            let index = hash % embeddingDimension

            // Увеличиваем значение в соответствующей позиции
            embedding[index] += 1.0
        }

        return embedding
    }

    /// Нормализация вектора (L2 norm)
    private func normalizeVector(_ vector: [Float]) -> [Float] {
        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })

        guard magnitude > 0 else {
            return vector
        }

        return vector.map { $0 / magnitude }
    }

    // MARK: - Tokenization

    /// Простая токенизация (для будущей CoreML модели)
    private func tokenize(_ text: String) -> [Int32] {
        // Используем NLTokenizer от Apple
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var tokens: [Int32] = []

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            let hash = abs(word.lowercased().hashValue)
            let tokenId = Int32(hash % 50000) // Vocabulary size = 50k
            tokens.append(tokenId)

            return tokens.count < maxLength
        }

        return tokens
    }

    // MARK: - Batch Embedding

    /// Генерирует embeddings для нескольких текстов одновременно
    func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        // TODO: Оптимизировать с помощью batch inference в CoreML

        var embeddings: [[Float]] = []

        for text in texts {
            let embedding = try await embed(text)
            embeddings.append(embedding)
        }

        return embeddings
    }

    // MARK: - Semantic Similarity

    /// Вычисляет semantic similarity между двумя текстами
    func semanticSimilarity(_ text1: String, _ text2: String) async throws -> Float {
        let embedding1 = try await embed(text1)
        let embedding2 = try await embed(text2)

        return cosineSimilarity(embedding1, embedding2)
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
}

// MARK: - Errors

enum EmbeddingError: Error {
    case modelNotLoaded
    case invalidOutput
    case tokenizationFailed
}

// MARK: - Future CoreML Model Input/Output

/*
// Эти структуры понадобятся когда добавим реальную CoreML модель

struct SentenceEncoderInput: MLFeatureProvider {
    let tokens: MLMultiArray

    var featureNames: Set<String> {
        return ["tokens"]
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "tokens" {
            return MLFeatureValue(multiArray: tokens)
        }
        return nil
    }
}

struct SentenceEncoderOutput: MLFeatureProvider {
    let embedding: MLMultiArray

    var featureNames: Set<String> {
        return ["embedding"]
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "embedding" {
            return MLFeatureValue(multiArray: embedding)
        }
        return nil
    }
}
*/
