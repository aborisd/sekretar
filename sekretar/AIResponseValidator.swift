import Foundation

// MARK: - AI Response Validator (из ai_calendar_production_plan_v4.md, Section 2)

/// Валидирует и улучшает качество AI ответов
/// Проверяет: factual accuracy, actionability, consistency, safety
class AIResponseValidator {

    // MARK: - Sub-Validators

    private let validators: [any ResponseValidator]

    init() {
        self.validators = [
            FactualAccuracyValidator(),
            ActionabilityValidator(),
            ConsistencyValidator(),
            SafetyValidator()
        ]
    }

    // MARK: - Main Validation

    /// Валидирует и при необходимости улучшает ответ AI
    func validateAndImprove(
        response: AIResponse,
        context: ValidationContext
    ) async throws -> ValidatedResponse {

        var currentResponse = response
        var warnings: [ValidationWarning] = []

        // 1. Проверка фактической точности
        let accuracyCheck = await checkFactualAccuracy(currentResponse, context: context)
        if !accuracyCheck.passed {
            warnings.append(.factualInaccuracy(accuracyCheck.issues))

            // Попытка регенерации с исправлениями
            currentResponse = try await regenerateWithCorrections(
                currentResponse,
                corrections: accuracyCheck.corrections
            )
        }

        // 2. Проверка выполнимости действий
        if currentResponse.actionRequired {
            let feasibilityCheck = await verifyActionFeasibility(currentResponse.action)

            if !feasibilityCheck.feasible {
                warnings.append(.unfeasibleAction(feasibilityCheck.reason))

                // Предлагаем альтернативы
                currentResponse = try await suggestAlternatives(currentResponse)
            }
        }

        // 3. Проверка консистентности с историей
        let conflicts = await checkConsistency(currentResponse, history: context.history)
        if !conflicts.isEmpty {
            warnings.append(.consistencyConflict(conflicts))

            // Разрешаем конфликты
            currentResponse = try await resolveConflicts(currentResponse, conflicts: conflicts)
        }

        // 4. Safety check
        let safetyCheck = await checkSafety(currentResponse)
        if !safetyCheck.passed {
            warnings.append(.safetyIssue(safetyCheck.issues))

            // Safety issues - критичны, не пропускаем
            throw ValidationError.safetyViolation(safetyCheck.issues)
        }

        // Вычисляем итоговый confidence
        let confidence = calculateConfidence(currentResponse, warnings: warnings)

        return ValidatedResponse(
            original: response,
            validated: currentResponse,
            isValidated: true,
            confidence: confidence,
            warnings: warnings
        )
    }

    // MARK: - Validation Steps

    private func checkFactualAccuracy(
        _ response: AIResponse,
        context: ValidationContext
    ) async -> AccuracyCheckResult {

        // Проверяем даты
        if let dateStr = response.extractedData["dueDate"] as? String {
            // Валидация что дата в будущем (для задач)
            if let date = ISO8601DateFormatter().date(from: dateStr),
               date < Date() {
                return AccuracyCheckResult(
                    passed: false,
                    issues: ["Дата в прошлом для новой задачи"],
                    corrections: ["Использовать ближайшую дату в будущем"]
                )
            }
        }

        // Проверяем логичность времени
        if let startTime = response.extractedData["startTime"] as? Date,
           let endTime = response.extractedData["endTime"] as? Date,
           endTime <= startTime {
            return AccuracyCheckResult(
                passed: false,
                issues: ["Время окончания раньше времени начала"],
                corrections: ["Скорректировать время окончания"]
            )
        }

        // Проверяем наличие обязательных полей
        if response.action == "createTask" || response.action == "createEvent" {
            guard let title = response.extractedData["title"] as? String,
                  !title.isEmpty else {
                return AccuracyCheckResult(
                    passed: false,
                    issues: ["Отсутствует название задачи/события"],
                    corrections: ["Извлечь название из исходного текста"]
                )
            }
        }

        return AccuracyCheckResult(passed: true, issues: [], corrections: [])
    }

    private func verifyActionFeasibility(_ action: String?) async -> FeasibilityCheckResult {
        guard let action = action else {
            return FeasibilityCheckResult(feasible: false, reason: "Действие не определено")
        }

        // Проверяем что действие поддерживается
        let supportedActions = [
            "createTask", "updateTask", "deleteTask",
            "createEvent", "updateEvent", "deleteEvent",
            "scheduleTask", "prioritizeTasks"
        ]

        if !supportedActions.contains(action) {
            return FeasibilityCheckResult(
                feasible: false,
                reason: "Действие '\(action)' не поддерживается"
            )
        }

        // Проверяем что есть необходимые данные для действия
        // (специфичные проверки для каждого типа)

        return FeasibilityCheckResult(feasible: true, reason: nil)
    }

    private func checkConsistency(
        _ response: AIResponse,
        history: [HistoricalAction]
    ) async -> [ConsistencyConflict] {

        var conflicts: [ConsistencyConflict] = []

        // Проверяем дублирование задач
        if response.action == "createTask",
           let title = response.extractedData["title"] as? String {

            for historical in history {
                if historical.action == "createTask",
                   let historicalTitle = historical.data["title"] as? String,
                   title.lowercased() == historicalTitle.lowercased() {

                    // Проверяем временную близость (если создали недавно)
                    if Date().timeIntervalSince(historical.timestamp) < 3600 { // 1 час
                        conflicts.append(.duplicateTask(
                            original: historicalTitle,
                            new: title,
                            timeDifference: Date().timeIntervalSince(historical.timestamp)
                        ))
                    }
                }
            }
        }

        // Проверяем конфликты по времени для событий
        if response.action == "createEvent",
           let startTime = response.extractedData["startTime"] as? Date,
           let endTime = response.extractedData["endTime"] as? Date {

            for historical in history {
                if historical.action == "createEvent",
                   let histStart = historical.data["startTime"] as? Date,
                   let histEnd = historical.data["endTime"] as? Date {

                    // Проверяем пересечение времени
                    if startTime < histEnd && endTime > histStart {
                        conflicts.append(.timeOverlap(
                            existingEvent: historical.data["title"] as? String ?? "Событие",
                            newEvent: response.extractedData["title"] as? String ?? "Новое событие",
                            overlapDuration: min(endTime, histEnd).timeIntervalSince(max(startTime, histStart))
                        ))
                    }
                }
            }
        }

        return conflicts
    }

    private func checkSafety(_ response: AIResponse) async -> SafetyCheckResult {
        var issues: [String] = []

        // Проверяем на вредоносный контент
        if let title = response.extractedData["title"] as? String {
            // Проверка на SQL injection patterns (базовая)
            if title.contains("DROP") || title.contains("DELETE") || title.contains("--") {
                issues.append("Потенциально опасный контент в названии")
            }

            // Проверка на XSS patterns
            if title.contains("<script>") || title.contains("javascript:") {
                issues.append("Потенциальный XSS в содержимом")
            }
        }

        // Проверяем что не пытаемся удалить все данные
        if response.action == "deleteTask" || response.action == "deleteEvent" {
            guard response.extractedData["id"] != nil ||
                  response.extractedData["title"] != nil else {
                issues.append("Попытка удаления без идентификатора")
                return SafetyCheckResult(passed: false, issues: issues)
            }
        }

        return SafetyCheckResult(passed: issues.isEmpty, issues: issues)
    }

    // MARK: - Improvement Methods

    private func regenerateWithCorrections(
        _ response: AIResponse,
        corrections: [String]
    ) async throws -> AIResponse {

        // TODO: Интегрировать с LLM для регенерации
        // Пока возвращаем исходный response с warnings
        var improved = response
        improved.metadata["applied_corrections"] = corrections
        return improved
    }

    private func suggestAlternatives(_ response: AIResponse) async throws -> AIResponse {
        // TODO: Использовать LLM для генерации альтернатив
        var improved = response
        improved.metadata["has_alternatives"] = true
        return improved
    }

    private func resolveConflicts(
        _ response: AIResponse,
        conflicts: [ConsistencyConflict]
    ) async throws -> AIResponse {

        var resolved = response

        for conflict in conflicts {
            switch conflict {
            case .duplicateTask:
                // Предлагаем обновить существующую задачу вместо создания новой
                resolved.action = "updateTask"
                resolved.metadata["conflict_resolution"] = "update_instead_of_create"

            case .timeOverlap(let existing, let new, let duration):
                // Сдвигаем время нового события
                if let startTime = resolved.extractedData["startTime"] as? Date,
                   let endTime = resolved.extractedData["endTime"] as? Date {

                    let shiftedStart = startTime.addingTimeInterval(duration + 300) // +5 минут буфер
                    let shiftedEnd = endTime.addingTimeInterval(duration + 300)

                    resolved.extractedData["startTime"] = shiftedStart
                    resolved.extractedData["endTime"] = shiftedEnd
                    resolved.metadata["time_shifted"] = true
                }
            }
        }

        return resolved
    }

    private func calculateConfidence(
        _ response: AIResponse,
        warnings: [ValidationWarning]
    ) -> Double {

        var confidence = response.confidence

        // Снижаем confidence за каждый warning
        for warning in warnings {
            switch warning {
            case .factualInaccuracy:
                confidence *= 0.8
            case .unfeasibleAction:
                confidence *= 0.7
            case .consistencyConflict:
                confidence *= 0.9
            case .safetyIssue:
                confidence *= 0.5 // Критично
            }
        }

        return max(0.0, min(1.0, confidence))
    }
}

// MARK: - Protocol for Validators

protocol ResponseValidator {
    func validate(_ response: AIResponse, context: ValidationContext) async -> ValidationResult
}

// MARK: - Concrete Validators

struct FactualAccuracyValidator: ResponseValidator {
    func validate(_ response: AIResponse, context: ValidationContext) async -> ValidationResult {
        // Проверка фактов
        return ValidationResult(passed: true, issues: [])
    }
}

struct ActionabilityValidator: ResponseValidator {
    func validate(_ response: AIResponse, context: ValidationContext) async -> ValidationResult {
        // Проверка выполнимости
        return ValidationResult(passed: true, issues: [])
    }
}

struct ConsistencyValidator: ResponseValidator {
    func validate(_ response: AIResponse, context: ValidationContext) async -> ValidationResult {
        // Проверка консистентности
        return ValidationResult(passed: true, issues: [])
    }
}

struct SafetyValidator: ResponseValidator {
    func validate(_ response: AIResponse, context: ValidationContext) async -> ValidationResult {
        // Safety проверка
        return ValidationResult(passed: true, issues: [])
    }
}

// MARK: - Data Models

struct AIResponse {
    var action: String?
    var extractedData: [String: Any]
    var confidence: Double
    var metadata: [String: Any]

    var actionRequired: Bool {
        return action != nil
    }
}

struct ValidationContext {
    let history: [HistoricalAction]
    let userPreferences: [String: Any]
    let currentContext: [String: Any]
}

struct HistoricalAction {
    let action: String
    let data: [String: Any]
    let timestamp: Date
}

struct ValidatedResponse {
    let original: AIResponse
    let validated: AIResponse
    let isValidated: Bool
    let confidence: Double
    let warnings: [ValidationWarning]
}

enum ValidationWarning {
    case factualInaccuracy([String])
    case unfeasibleAction(String?)
    case consistencyConflict([ConsistencyConflict])
    case safetyIssue([String])
}

enum ConsistencyConflict {
    case duplicateTask(original: String, new: String, timeDifference: TimeInterval)
    case timeOverlap(existingEvent: String, newEvent: String, overlapDuration: TimeInterval)
}

struct AccuracyCheckResult {
    let passed: Bool
    let issues: [String]
    let corrections: [String]
}

struct FeasibilityCheckResult {
    let feasible: Bool
    let reason: String?
}

struct SafetyCheckResult {
    let passed: Bool
    let issues: [String]
}

struct ValidationResult {
    let passed: Bool
    let issues: [String]
}

enum ValidationError: Error {
    case safetyViolation([String])
    case criticalValidationFailure(String)
}
