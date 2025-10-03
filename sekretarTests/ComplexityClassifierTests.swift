import XCTest
@testable import sekretar

/// Unit тесты для ComplexityClassifier
/// Проверяют точность классификации запросов по сложности
final class ComplexityClassifierTests: XCTestCase {

    var classifier: ComplexityClassifier!

    override func setUp() {
        super.setUp()
        classifier = ComplexityClassifier()
    }

    override func tearDown() {
        classifier = nil
        super.tearDown()
    }

    // MARK: - Simple Queries Tests

    func testSimpleCreateTask() {
        let input = "создай задачу купить молоко"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .simple, "Простая задача должна быть классифицирована как simple")
    }

    func testSimpleCreateTaskEnglish() {
        let input = "create task buy milk"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .simple)
    }

    func testSimpleDelete() {
        let input = "удали задачу"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .simple)
    }

    func testSimpleShow() {
        let input = "покажи мои задачи на сегодня"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .simple)
    }

    func testSimpleAddEnglish() {
        let input = "add new task"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .simple)
    }

    // MARK: - Medium Queries Tests

    func testMediumReschedule() {
        let input = "перенеси встречу на завтра"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .medium, "Перенос события должен быть medium сложности")
    }

    func testMediumOrganize() {
        let input = "организуй мои задачи по проектам"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .medium)
    }

    func testMediumFindTime() {
        let input = "найди время для встречи в пятницу"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .medium)
    }

    func testMediumSuggest() {
        let input = "подбери лучшее время для задачи"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .medium)
    }

    // MARK: - Complex Queries Tests

    func testComplexBreakdown() {
        let input = "разбей проект на подзадачи и распредели по неделям"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .complex, "Декомпозиция проекта - сложная задача")
    }

    func testComplexAnalyze() {
        let input = "проанализируй мою продуктивность за месяц"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .complex)
    }

    func testComplexOptimize() {
        let input = "оптимизируй расписание с учетом приоритетов"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .complex)
    }

    func testComplexStrategy() {
        let input = "предложи стратегию достижения цели"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .complex)
    }

    func testComplexCompare() {
        let input = "сравни эффективность моей работы в этом и прошлом месяце"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .complex)
    }

    // MARK: - Edge Cases Tests

    func testSimpleWithComplexModifiers() {
        let input = "создай задачу купить молоко и также хлеб с учетом бюджета"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .medium, "Простая задача с модификаторами становится medium")
    }

    func testLongQueryBecomesComplex() {
        let input = String(repeating: "создай задачу ", count: 20) + "с множеством деталей"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .complex, "Длинный запрос (>100 символов) должен быть complex")
    }

    func testMultipleQuestions() {
        let input = "когда у меня встреча? что еще запланировано? есть конфликты?"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .complex, "Множественные вопросы - сложный запрос")
    }

    func testComplexGrammar() {
        let input = "создай задачу, потому что мне нужно, несмотря на занятость, выполнить это"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .complex, "Сложная грамматика повышает сложность")
    }

    func testEmptyString() {
        let input = ""
        let result = classifier.classify(input)

        XCTAssertEqual(result, .medium, "Пустая строка классифицируется как medium по умолчанию")
    }

    // MARK: - Detailed Classification Tests

    func testDetailedClassificationSimple() {
        let input = "добавь задачу позвонить маме"
        let detailed = classifier.classifyDetailed(input)

        XCTAssertEqual(detailed.complexity, .simple)
        XCTAssertGreaterThan(detailed.confidence, 0.8, "Простые паттерны дают высокую уверенность")
        XCTAssertFalse(detailed.matchedPatterns.isEmpty, "Должны быть найдены паттерны")
        XCTAssertTrue(detailed.reasoning.contains("Matched patterns"), "Должно быть объяснение")
    }

    func testDetailedClassificationComplex() {
        let input = "проанализируй загруженность и оптимизируй расписание"
        let detailed = classifier.classifyDetailed(input)

        XCTAssertEqual(detailed.complexity, .complex)
        XCTAssertGreaterThan(detailed.confidence, 0.8)
        XCTAssertTrue(detailed.matchedPatterns.contains { $0.contains("complex") })
    }

    func testDetailedClassificationWithLowConfidence() {
        let input = "хммм... может быть сделать что-то?"
        let detailed = classifier.classifyDetailed(input)

        // Не должно совпасть с четкими паттернами
        XCTAssertLessThan(detailed.confidence, 0.9, "Нечеткий запрос - низкая уверенность")
    }

    // MARK: - Cost Estimation Tests

    func testSimpleCostEstimation() {
        let complexity = Complexity.simple
        let cost = complexity.estimatedCostPer1KTokens

        XCTAssertEqual(cost.input, 0.075, "Gemini Flash input cost")
        XCTAssertEqual(cost.output, 0.30, "Gemini Flash output cost")
    }

    func testMediumCostEstimation() {
        let complexity = Complexity.medium
        let cost = complexity.estimatedCostPer1KTokens

        XCTAssertEqual(cost.input, 0.15, "GPT-4o-mini input cost")
        XCTAssertEqual(cost.output, 0.60, "GPT-4o-mini output cost")
    }

    func testComplexCostEstimation() {
        let complexity = Complexity.complex
        let cost = complexity.estimatedCostPer1KTokens

        XCTAssertEqual(cost.input, 3.0, "Claude Sonnet input cost")
        XCTAssertEqual(cost.output, 15.0, "Claude Sonnet output cost")
    }

    // MARK: - Russian vs English Tests

    func testRussianSimpleQuery() {
        let input = "создай задачу сходить в магазин"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .simple)
    }

    func testEnglishSimpleQuery() {
        let input = "create task go to store"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .simple)
    }

    func testRussianComplexQuery() {
        let input = "проанализируй паттерны и предложи улучшения"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .complex)
    }

    func testEnglishComplexQuery() {
        let input = "analyze patterns and suggest improvements"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .complex)
    }

    // MARK: - Performance Tests

    func testClassificationPerformance() {
        let inputs = [
            "создай задачу",
            "проанализируй продуктивность",
            "найди время для встречи",
            "оптимизируй расписание на неделю",
            "покажи задачи на сегодня"
        ]

        measure {
            for input in inputs {
                _ = classifier.classify(input)
            }
        }
    }

    func testDetailedClassificationPerformance() {
        let input = "разбей проект на подзадачи и распредели по приоритетам"

        measure {
            _ = classifier.classifyDetailed(input)
        }
    }

    // MARK: - Real-World Examples Tests

    func testRealWorldExample1() {
        let input = "Создай задачу подготовить презентацию к встрече завтра в 14:00"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .simple, "Создание задачи с деталями - все еще simple")
    }

    func testRealWorldExample2() {
        let input = "Найди оптимальное время для созвона с командой на следующей неделе"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .medium, "Поиск времени - medium сложность")
    }

    func testRealWorldExample3() {
        let input = "Проанализируй мои задачи за месяц, найди паттерны прокрастинации и предложи стратегию улучшения"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .complex, "Анализ + стратегия - complex")
    }

    func testRealWorldExample4() {
        let input = "Перенеси все встречи на час позже из-за утренней задержки"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .medium, "Массовый перенос - medium")
    }

    func testRealWorldExample5() {
        let input = "Удали старые задачи"
        let result = classifier.classify(input)

        XCTAssertEqual(result, .simple, "Простое удаление - simple")
    }
}
