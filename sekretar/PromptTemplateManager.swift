import Foundation

/// Manages prompt templates with versioning and variable substitution
public final class PromptTemplateManager {

    // MARK: - Template Types

    public enum TemplateType: String {
        case intentDetection = "intent_detection"
        case taskAnalysis = "task_analysis"
        case eventParsing = "event_parsing"
        case scheduleOptimization = "schedule_optimization"

        var fileName: String {
            "\(rawValue).v1.txt"
        }
    }

    // MARK: - Properties

    private let promptsDirectory: URL
    private var templateCache: [TemplateType: String] = [:]
    private let systemPrompt: String

    // MARK: - Initialization

    public init() {
        // Get prompts directory
        if let bundleURL = Bundle.main.url(forResource: "Prompts", withExtension: nil) {
            self.promptsDirectory = bundleURL
        } else {
            // Fallback to relative path during development
            let currentFile = URL(fileURLWithPath: #file)
            self.promptsDirectory = currentFile
                .deletingLastPathComponent()
                .appendingPathComponent("Prompts")
        }

        // Load system prompt
        let systemPromptPath = promptsDirectory
            .appendingPathComponent("system_prompts")
            .appendingPathComponent("sekretar_personality.txt")

        if let content = try? String(contentsOf: systemPromptPath, encoding: .utf8) {
            self.systemPrompt = content
        } else {
            // Fallback system prompt
            self.systemPrompt = """
            You are Sekretar, an intelligent personal assistant focused on productivity and time management.
            Be concise, actionable, and helpful. Support both Russian and English languages.
            """
        }

        // Pre-load templates
        loadAllTemplates()
    }

    // MARK: - Public Methods

    /// Get system prompt for personality
    public func getSystemPrompt() -> String {
        return systemPrompt
    }

    /// Load and render a template with variable substitution
    public func render(template: TemplateType, variables: [String: String]) throws -> String {
        guard let templateContent = getTemplate(template) else {
            throw TemplateError.templateNotFound(template)
        }

        return substitute(variables: variables, in: templateContent)
    }

    /// Get raw template content
    public func getTemplate(_ type: TemplateType) -> String? {
        // Check cache first
        if let cached = templateCache[type] {
            return cached
        }

        // Load from disk
        let templatePath = promptsDirectory.appendingPathComponent(type.fileName)

        guard let content = try? String(contentsOf: templatePath, encoding: .utf8) else {
            // Return fallback template
            return getFallbackTemplate(type)
        }

        // Cache for future use
        templateCache[type] = content
        return content
    }

    /// Clear template cache (useful for hot-reloading in development)
    public func clearCache() {
        templateCache.removeAll()
    }

    /// Reload all templates
    public func reloadTemplates() {
        clearCache()
        loadAllTemplates()
    }

    // MARK: - Private Methods

    private func loadAllTemplates() {
        for type in [TemplateType.intentDetection, .taskAnalysis, .eventParsing, .scheduleOptimization] {
            _ = getTemplate(type) // This will cache the template
        }
    }

    private func substitute(variables: [String: String], in template: String) -> String {
        var result = template

        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }

        // Check for unsubstituted variables and log warning
        let pattern = "\\{([^}]+)\\}"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
            if !matches.isEmpty {
                for match in matches {
                    if let range = Range(match.range(at: 1), in: result) {
                        let varName = String(result[range])
                        print("⚠️ Unsubstituted variable: {\(varName)}")
                    }
                }
            }
        }

        return result
    }

    private func getFallbackTemplate(_ type: TemplateType) -> String {
        switch type {
        case .intentDetection:
            return """
            Analyze the user's input and determine their intent.

            User Input: {user_input}
            Current date/time: {current_datetime}

            Return a JSON object with the intent classification.
            Example: {"intent": "create_task", "confidence": 0.9}

            Available intents:
            - create_task, modify_task, delete_task, complete_task
            - schedule_task, create_event, modify_event, delete_event
            - ask_question, request_suggestion, show_tasks, show_schedule
            - analyze_productivity, bulk_operation, unclear

            IMPORTANT: Return ONLY valid JSON, no additional text.
            """

        case .taskAnalysis:
            return """
            Analyze this task and provide recommendations.

            Task Title: {task_title}
            Description: {task_description}
            Current Priority: {current_priority}

            Return a JSON object with:
            - suggested_priority (0-3)
            - estimated_duration_minutes (integer)
            - suggested_tags (array of strings)
            - potential_subtasks (array of strings)
            - category (string)
            - complexity (simple|moderate|complex|expert)
            - reasoning (brief explanation)

            IMPORTANT: Return ONLY valid JSON, no additional text.
            """

        case .eventParsing:
            return """
            Parse this event description into structured data.

            Input: {user_input}

            Return a JSON object with:
            - title (string)
            - start_iso (ISO 8601 datetime)
            - end_iso (ISO 8601 datetime, optional)
            - all_day (boolean)
            - location (string, optional)
            - description (string, optional)

            IMPORTANT: Return ONLY valid JSON, no additional text.
            """

        case .scheduleOptimization:
            return """
            Optimize the schedule for these tasks.

            Tasks: {tasks_json}
            Available Slots: {available_slots}

            Return a JSON object with:
            - reasoning (string)
            - productivity_score (0-100)
            - items (array of scheduled tasks)

            IMPORTANT: Return ONLY valid JSON, no additional text.
            """
        }
    }

    // MARK: - Errors

    public enum TemplateError: LocalizedError {
        case templateNotFound(TemplateType)
        case invalidTemplate(String)

        public var errorDescription: String? {
            switch self {
            case .templateNotFound(let type):
                return "Template not found: \(type.rawValue)"
            case .invalidTemplate(let reason):
                return "Invalid template: \(reason)"
            }
        }
    }
}

// MARK: - Template Preview Helper

#if DEBUG
extension PromptTemplateManager {
    /// Preview a rendered template with sample data
    public func preview(template: TemplateType) -> String {
        let sampleVariables: [String: String]

        switch template {
        case .intentDetection:
            sampleVariables = [
                "user_input": "Создай задачу позвонить маме завтра в 15:00",
                "current_datetime": ISO8601DateFormatter().string(from: Date()),
                "timezone": "Europe/Moscow",
                "language": "ru"
            ]

        case .taskAnalysis:
            sampleVariables = [
                "task_title": "Подготовить квартальный отчет",
                "task_description": "Собрать данные из всех отделов и проанализировать KPI",
                "current_priority": "2",
                "due_date": ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400 * 7)),
                "additional_context": "",
                "work_hours": "9:00-18:00",
                "energy_patterns": "High: 9-12, Medium: 12-15, Low: 15-18",
                "preferred_duration": "30-60 minutes",
                "workload_level": "medium"
            ]

        case .eventParsing:
            sampleVariables = [
                "user_input": "Встреча с клиентом завтра в 14:30 на 1 час"
            ]

        case .scheduleOptimization:
            sampleVariables = [
                "tasks_json": "[{\"id\": \"1\", \"title\": \"Task 1\", \"priority\": 2}]",
                "available_slots": "[{\"start\": \"2025-10-03T09:00:00Z\", \"end\": \"2025-10-03T10:00:00Z\"}]"
            ]
        }

        do {
            return try render(template: template, variables: sampleVariables)
        } catch {
            return "Error previewing template: \(error.localizedDescription)"
        }
    }
}
#endif