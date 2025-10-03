import Foundation

// MARK: - Complexity Classifier (из ai_calendar_production_plan.md Week 3-4)

/// Классифицирует сложность запроса для выбора оптимальной LLM модели
/// Цель: снижение costs на 60-70% через intelligent routing
class ComplexityClassifier {

    // MARK: - Pattern Definitions

    /// Простые паттерны → Gemini Flash ($0.075/$0.30)
    private let simplePatterns: [String] = [
        "создай задачу", "create task",
        "удали", "delete",
        "измени", "change", "rename",
        "покажи", "show me",
        "отметь", "mark as",
        "список", "list",
        "добавь", "add",
        "напомни", "remind",
        "когда", "when",
        "завтра", "tomorrow",
        "сегодня", "today"
    ]

    /// Сложные паттерны → Claude Sonnet ($3/$15)
    private let complexPatterns: [String] = [
        "разбей на подзадачи", "break down",
        "проанализируй", "analyze",
        "оптимизируй", "optimize",
        "предложи стратегию", "suggest strategy",
        "что если", "what if",
        "сравни", "compare",
        "декомпозируй", "decompose",
        "приоритизируй", "prioritize",
        "найди паттерны", "find patterns",
        "спланируй", "plan out",
        "как лучше", "what's the best way"
    ]

    /// Средние паттерны → GPT-4o-mini ($0.15/$0.60)
    private let mediumPatterns: [String] = [
        "перенеси", "reschedule",
        "организуй", "organize",
        "сгруппируй", "group",
        "найди время", "find time",
        "подбери", "suggest",
        "когда свободен", "when am I free"
    ]

    // MARK: - Classification

    /// Классифицирует сложность запроса
    func classify(_ input: String) -> Complexity {
        let text = input.lowercased()

        // 1. Проверка на простые паттерны
        for pattern in simplePatterns {
            if text.contains(pattern) {
                // Дополнительная проверка: если есть сложные модификаторы, повышаем сложность
                if hasComplexModifiers(text) {
                    return .medium
                }
                return .simple
            }
        }

        // 2. Проверка на сложные паттерны
        for pattern in complexPatterns {
            if text.contains(pattern) {
                return .complex
            }
        }

        // 3. Проверка на средние паттерны
        for pattern in mediumPatterns {
            if text.contains(pattern) {
                return .medium
            }
        }

        // 4. Эвристики на основе структуры запроса

        // Длинные запросы (>100 символов) обычно сложнее
        if text.count > 100 {
            return .complex
        }

        // Множественные вопросы или команды
        let questionMarks = text.filter { $0 == "?" }.count
        if questionMarks > 1 {
            return .complex
        }

        // Наличие сложных грамматических конструкций
        if hasComplexGrammar(text) {
            return .complex
        }

        // 5. По умолчанию - medium
        return .medium
    }

    /// Классифицирует с деталями (для debugging/analytics)
    func classifyDetailed(_ input: String) -> DetailedClassification {
        let complexity = classify(input)
        let matchedPatterns = findMatchedPatterns(input.lowercased())
        let confidence = calculateConfidence(input.lowercased(), matchedPatterns: matchedPatterns)

        return DetailedClassification(
            complexity: complexity,
            confidence: confidence,
            matchedPatterns: matchedPatterns,
            inputLength: input.count,
            reasoning: generateReasoning(complexity, matchedPatterns: matchedPatterns)
        )
    }

    // MARK: - Helper Methods

    /// Проверяет наличие сложных модификаторов
    private func hasComplexModifiers(_ text: String) -> Bool {
        let complexModifiers = [
            "и также", "плюс", "кроме того",
            "с учетом", "принимая во внимание",
            "в зависимости от",
            "and also", "plus", "additionally",
            "considering", "taking into account"
        ]

        return complexModifiers.contains { text.contains($0) }
    }

    /// Проверяет сложность грамматики
    private func hasComplexGrammar(_ text: String) -> Bool {
        // Множественные предложения
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        if sentences.count > 2 {
            return true
        }

        // Сложные союзы
        let complexConjunctions = [
            "потому что", "несмотря на", "в то время как",
            "однако", "тем не менее",
            "because", "although", "while", "however", "nevertheless"
        ]

        return complexConjunctions.contains { text.contains($0) }
    }

    /// Находит совпавшие паттерны
    private func findMatchedPatterns(_ text: String) -> [String] {
        var matched: [String] = []

        for pattern in simplePatterns where text.contains(pattern) {
            matched.append("simple:\(pattern)")
        }

        for pattern in mediumPatterns where text.contains(pattern) {
            matched.append("medium:\(pattern)")
        }

        for pattern in complexPatterns where text.contains(pattern) {
            matched.append("complex:\(pattern)")
        }

        return matched
    }

    /// Вычисляет уверенность в классификации
    private func calculateConfidence(_ text: String, matchedPatterns: [String]) -> Double {
        // Если нашли четкие паттерны - высокая уверенность
        if !matchedPatterns.isEmpty {
            return 0.9
        }

        // Если используем эвристики - средняя уверенность
        if text.count > 100 || hasComplexGrammar(text) {
            return 0.7
        }

        // По умолчанию - низкая уверенность
        return 0.5
    }

    /// Генерирует объяснение классификации
    private func generateReasoning(_ complexity: Complexity, matchedPatterns: [String]) -> String {
        if !matchedPatterns.isEmpty {
            return "Matched patterns: \(matchedPatterns.joined(separator: ", "))"
        }

        switch complexity {
        case .simple:
            return "Default classification for simple queries"
        case .medium:
            return "Moderate complexity based on heuristics"
        case .complex:
            return "High complexity based on length or grammar"
        }
    }
}

// MARK: - Data Models

enum Complexity: String, Codable {
    case simple   // CRUD, basic queries → Gemini Flash ($0.075/$0.30)
    case medium   // Scheduling, prioritization → GPT-4o-mini ($0.15/$0.60)
    case complex  // Planning, analysis → Claude Sonnet ($3/$15)

    var description: String {
        switch self {
        case .simple:
            return "Simple (Gemini Flash)"
        case .medium:
            return "Medium (GPT-4o-mini)"
        case .complex:
            return "Complex (Claude Sonnet)"
        }
    }

    var estimatedCostPer1KTokens: (input: Double, output: Double) {
        switch self {
        case .simple:
            return (0.075, 0.30)
        case .medium:
            return (0.15, 0.60)
        case .complex:
            return (3.0, 15.0)
        }
    }
}

struct DetailedClassification {
    let complexity: Complexity
    let confidence: Double
    let matchedPatterns: [String]
    let inputLength: Int
    let reasoning: String

    var summary: String {
        return """
        Complexity: \(complexity.description)
        Confidence: \(String(format: "%.1f%%", confidence * 100))
        Patterns: \(matchedPatterns.isEmpty ? "none" : matchedPatterns.joined(separator: ", "))
        Input length: \(inputLength) chars
        Reasoning: \(reasoning)
        """
    }
}
