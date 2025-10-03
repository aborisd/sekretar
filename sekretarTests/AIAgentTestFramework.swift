import XCTest
@testable import sekretar

// MARK: - AI Agent Test Framework (из ai_calendar_production_plan_v4.md, Section 4)

/// Специализированный фреймворк для тестирования AI агентов
/// Покрывает: functional tests, edge cases, stress testing, consistency
class AIAgentTestFramework: XCTestCase {

    // MARK: - Configuration

    private var testScenarios: [String: [TestScenario]] = [:]
    private var performanceBenchmarks: [String: PerformanceBenchmark] = [:]

    override func setUp() {
        super.setUp()
        loadTestScenarios()
        setupPerformanceBenchmarks()
    }

    // MARK: - Main Test Methods

    /// Полное тестирование AI агента
    func testAgent(_ agentName: String) async throws {
        let agent = createAgent(named: agentName)
        var results: [ScenarioResult] = []

        // 1. Функциональные тесты
        print("🧪 [AIAgentTest] Running functional tests for \(agentName)...")
        let functionalResults = try await runFunctionalTests(agent: agent)
        results.append(contentsOf: functionalResults)

        // 2. Edge cases
        print("🔍 [AIAgentTest] Testing edge cases...")
        let edgeCaseResults = try await testEdgeCases(agent: agent)
        results.append(contentsOf: edgeCaseResults)

        // 3. Стресс-тестирование
        print("💪 [AIAgentTest] Stress testing...")
        let stressResult = try await stressTest(
            agent: agent,
            concurrentRequests: 100,
            durationSeconds: 60
        )

        // 4. Консистентность ответов
        print("🎯 [AIAgentTest] Testing consistency...")
        let consistencyScore = try await testConsistency(
            agent: agent,
            sameInputIterations: 10
        )

        // Генерируем отчет
        let report = generateTestReport(
            agentName: agentName,
            functionalResults: results,
            stressResult: stressResult,
            consistencyScore: consistencyScore
        )

        print("\n📊 [AIAgentTest] Test Report:")
        print(report.summary)

        // Assertions
        XCTAssertGreaterThan(report.successRate, 0.90, "Success rate должен быть >90%")
        XCTAssertGreaterThan(consistencyScore, 0.85, "Consistency score должен быть >85%")
        XCTAssertLessThan(report.averageLatencyMs, 2000, "Average latency должна быть <2s")
    }

    // MARK: - Functional Tests

    private func runFunctionalTests(agent: AIAgent) async throws -> [ScenarioResult] {
        guard let scenarios = testScenarios[agent.name] else {
            return []
        }

        var results: [ScenarioResult] = []

        for scenario in scenarios {
            let result = try await runScenario(agent: agent, scenario: scenario)
            results.append(result)

            // Логируем результат
            let status = result.passed ? "✅" : "❌"
            print("  \(status) \(scenario.name): \(result.message)")
        }

        return results
    }

    private func runScenario(agent: AIAgent, scenario: TestScenario) async throws -> ScenarioResult {
        let startTime = Date()

        do {
            let output = try await agent.process(input: scenario.input)

            // Валидируем вывод
            let validationPassed = scenario.validator(output)

            let latencyMs = Date().timeIntervalSince(startTime) * 1000

            return ScenarioResult(
                scenarioName: scenario.name,
                passed: validationPassed,
                latencyMs: latencyMs,
                message: validationPassed ? "Success" : "Validation failed",
                output: output
            )
        } catch {
            return ScenarioResult(
                scenarioName: scenario.name,
                passed: false,
                latencyMs: 0,
                message: "Error: \(error.localizedDescription)",
                output: nil
            )
        }
    }

    // MARK: - Edge Case Testing

    private func testEdgeCases(agent: AIAgent) async throws -> [ScenarioResult] {
        let edgeCases = generateEdgeCases(for: agent.type)
        var results: [ScenarioResult] = []

        for testCase in edgeCases {
            let result = try await runScenario(agent: agent, scenario: testCase)
            results.append(result)
        }

        return results
    }

    private func generateEdgeCases(for agentType: AgentType) -> [TestScenario] {
        switch agentType {
        case .nlpParser:
            return [
                TestScenario(
                    name: "Empty input",
                    input: "",
                    validator: { output in
                        return output["error"] != nil
                    }
                ),
                TestScenario(
                    name: "Very long input (>10000 chars)",
                    input: String(repeating: "test ", count: 2000),
                    validator: { output in
                        return output["truncated"] != nil || output["error"] != nil
                    }
                ),
                TestScenario(
                    name: "Special characters",
                    input: "создай задачу <script>alert('xss')</script>",
                    validator: { output in
                        // Должен удалить опасные теги
                        return !(output["title"] as? String ?? "").contains("<script>")
                    }
                ),
                TestScenario(
                    name: "Mixed languages",
                    input: "create задачу tomorrow в 15:00",
                    validator: { output in
                        return output["dueDate"] != nil
                    }
                )
            ]

        case .intentDetector:
            return [
                TestScenario(
                    name: "Ambiguous intent",
                    input: "сделай что-нибудь",
                    validator: { output in
                        return (output["confidence"] as? Double ?? 1.0) < 0.6
                    }
                ),
                TestScenario(
                    name: "Multiple intents",
                    input: "создай задачу и удали событие",
                    validator: { output in
                        return (output["intents"] as? [Any])?.count ?? 0 >= 2
                    }
                )
            ]

        case .scheduler:
            return [
                TestScenario(
                    name: "Conflicting events",
                    input: ["event1": ["start": Date(), "end": Date().addingTimeInterval(3600)],
                           "event2": ["start": Date(), "end": Date().addingTimeInterval(1800)]],
                    validator: { output in
                        return output["conflict_detected"] as? Bool == true
                    }
                )
            ]
        }
    }

    // MARK: - Stress Testing

    private func stressTest(
        agent: AIAgent,
        concurrentRequests: Int,
        durationSeconds: TimeInterval
    ) async throws -> StressTestResult {

        var successCount = 0
        var errorCount = 0
        var latencies: [TimeInterval] = []

        let endTime = Date().addingTimeInterval(durationSeconds)

        // Создаем concurrent tasks
        await withTaskGroup(of: (success: Bool, latency: TimeInterval).self) { group in
            for i in 0..<concurrentRequests {
                group.addTask {
                    let startTime = Date()

                    do {
                        _ = try await agent.process(input: "тестовый запрос \(i)")
                        let latency = Date().timeIntervalSince(startTime)
                        return (true, latency)
                    } catch {
                        return (false, 0)
                    }
                }
            }

            // Собираем результаты
            for await result in group {
                if result.success {
                    successCount += 1
                    latencies.append(result.latency)
                } else {
                    errorCount += 1
                }
            }
        }

        // Вычисляем метрики
        let successRate = Double(successCount) / Double(concurrentRequests)
        let averageLatency = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
        let p95Latency = latencies.isEmpty ? 0 : calculatePercentile(latencies, percentile: 0.95)

        return StressTestResult(
            totalRequests: concurrentRequests,
            successCount: successCount,
            errorCount: errorCount,
            successRate: successRate,
            averageLatencyMs: averageLatency * 1000,
            p95LatencyMs: p95Latency * 1000,
            durationSeconds: durationSeconds
        )
    }

    // MARK: - Consistency Testing

    private func testConsistency(
        agent: AIAgent,
        sameInputIterations: Int
    ) async throws -> Double {

        let testInput = "создай задачу купить молоко завтра в 14:00"
        var outputs: [[String: Any]] = []

        // Запускаем одинаковый input несколько раз
        for _ in 0..<sameInputIterations {
            let output = try await agent.process(input: testInput)
            outputs.append(output)
        }

        // Проверяем консистентность
        var consistentFields = 0
        var totalFields = 0

        guard let firstOutput = outputs.first else {
            return 0.0
        }

        for key in firstOutput.keys {
            totalFields += 1

            let firstValue = String(describing: firstOutput[key] ?? "")
            let allSame = outputs.allSatisfy { output in
                String(describing: output[key] ?? "") == firstValue
            }

            if allSame {
                consistentFields += 1
            }
        }

        return totalFields == 0 ? 0.0 : Double(consistentFields) / Double(totalFields)
    }

    // MARK: - Helper Methods

    private func createAgent(named: String) -> AIAgent {
        // TODO: Factory для создания агентов
        return MockAIAgent(name: named, type: .nlpParser)
    }

    private func loadTestScenarios() {
        // Загружаем тестовые сценарии для разных агентов
        testScenarios = [
            "NLPParser": [
                TestScenario(
                    name: "Simple task creation",
                    input: "создай задачу купить молоко",
                    validator: { output in
                        return output["action"] as? String == "createTask" &&
                               (output["title"] as? String)?.contains("молоко") == true
                    }
                ),
                TestScenario(
                    name: "Task with date",
                    input: "создай задачу позвонить маме завтра в 15:00",
                    validator: { output in
                        return output["action"] as? String == "createTask" &&
                               output["dueDate"] != nil
                    }
                )
            ]
        ]
    }

    private func setupPerformanceBenchmarks() {
        performanceBenchmarks = [
            "NLPParser": PerformanceBenchmark(
                targetLatencyMs: 50,
                targetSuccessRate: 0.95
            ),
            "IntentDetector": PerformanceBenchmark(
                targetLatencyMs: 100,
                targetSuccessRate: 0.90
            )
        ]
    }

    private func calculatePercentile(_ values: [TimeInterval], percentile: Double) -> TimeInterval {
        let sorted = values.sorted()
        let index = Int(Double(sorted.count) * percentile)
        return sorted[min(index, sorted.count - 1)]
    }

    private func generateTestReport(
        agentName: String,
        functionalResults: [ScenarioResult],
        stressResult: StressTestResult,
        consistencyScore: Double
    ) -> TestReport {

        let successCount = functionalResults.filter { $0.passed }.count
        let successRate = Double(successCount) / Double(functionalResults.count)
        let averageLatency = functionalResults.map { $0.latencyMs }.reduce(0, +) / Double(functionalResults.count)

        return TestReport(
            agentName: agentName,
            successRate: successRate,
            averageLatencyMs: averageLatency,
            consistencyScore: consistencyScore,
            stressTestResult: stressResult,
            recommendations: generateRecommendations(
                successRate: successRate,
                latency: averageLatency,
                consistency: consistencyScore
            )
        )
    }

    private func generateRecommendations(
        successRate: Double,
        latency: Double,
        consistency: Double
    ) -> [String] {

        var recommendations: [String] = []

        if successRate < 0.90 {
            recommendations.append("⚠️ Success rate низкий - улучшить error handling")
        }

        if latency > 1000 {
            recommendations.append("⚠️ Latency высокая - оптимизировать обработку")
        }

        if consistency < 0.85 {
            recommendations.append("⚠️ Consistency низкая - стабилизировать алгоритм")
        }

        if recommendations.isEmpty {
            recommendations.append("✅ Все метрики в норме")
        }

        return recommendations
    }
}

// MARK: - Data Models

protocol AIAgent {
    var name: String { get }
    var type: AgentType { get }

    func process(input: Any) async throws -> [String: Any]
}

enum AgentType {
    case nlpParser
    case intentDetector
    case scheduler
}

struct TestScenario {
    let name: String
    let input: Any
    let validator: ([String: Any]) -> Bool
}

struct ScenarioResult {
    let scenarioName: String
    let passed: Bool
    let latencyMs: Double
    let message: String
    let output: [String: Any]?
}

struct StressTestResult {
    let totalRequests: Int
    let successCount: Int
    let errorCount: Int
    let successRate: Double
    let averageLatencyMs: Double
    let p95LatencyMs: Double
    let durationSeconds: TimeInterval
}

struct PerformanceBenchmark {
    let targetLatencyMs: Double
    let targetSuccessRate: Double
}

struct TestReport {
    let agentName: String
    let successRate: Double
    let averageLatencyMs: Double
    let consistencyScore: Double
    let stressTestResult: StressTestResult
    let recommendations: [String]

    var summary: String {
        return """
        Agent: \(agentName)
        Success Rate: \(String(format: "%.1f%%", successRate * 100))
        Average Latency: \(String(format: "%.0fms", averageLatencyMs))
        Consistency: \(String(format: "%.1f%%", consistencyScore * 100))
        Stress Test: \(stressTestResult.successCount)/\(stressTestResult.totalRequests) успешных
        P95 Latency: \(String(format: "%.0fms", stressTestResult.p95LatencyMs))

        Recommendations:
        \(recommendations.map { "  - \($0)" }.joined(separator: "\n"))
        """
    }
}

// MARK: - Mock Agent for Testing

struct MockAIAgent: AIAgent {
    let name: String
    let type: AgentType

    func process(input: Any) async throws -> [String: Any] {
        // Mock implementation
        if let stringInput = input as? String {
            return [
                "action": "createTask",
                "title": stringInput,
                "confidence": 0.95
            ]
        }

        return [:]
    }
}
