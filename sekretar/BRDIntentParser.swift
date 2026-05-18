import Foundation

// MARK: - BRD JSON Contract (строки 296-323)
/**
 Формат ответа ИИ по BRD:
 {
   "action": "createTask|updateTask|deleteTask|createEvent|updateEvent|deleteEvent|suggestTime|prioritize|summarize",
   "payload": { поля сущности },
   "meta": {
     "confidence": 0.0-1.0,
     "requiresConfirmation": true|false
   }
 }
*/

struct BRDIntent: Codable {
    let action: String
    let payload: [String: AnyCodable]
    let meta: BRDMeta

    struct BRDMeta: Codable {
        let confidence: Double
        let requiresConfirmation: Bool

        enum CodingKeys: String, CodingKey {
            case confidence
            case requiresConfirmation = "requiresConfirmation"
        }
    }
}

// MARK: - BRD Intent Parser (JSON контракт)
// Note: AnyCodable helper is defined in OfflineSyncService.swift
class BRDIntentParser {

    static func parseIntent(from json: String) throws -> AIAction {
        guard let data = json.data(using: .utf8) else {
            throw NSError(domain: "BRDParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }

        let brdIntent = try JSONDecoder().decode(BRDIntent.self, from: data)

        // Map BRD action to AIActionType
        let actionType = mapBRDAction(brdIntent.action)

        // Convert payload to [String: Any]
        let payload = brdIntent.payload.mapValues(\.value)

        // Extract title and description from payload
        let title = extractTitle(from: brdIntent.action, payload: payload)
        let description = extractDescription(from: payload, actionType: actionType)

        return AIAction(
            type: actionType,
            title: title,
            description: description,
            confidence: brdIntent.meta.confidence,
            requiresConfirmation: brdIntent.meta.requiresConfirmation,
            payload: payload
        )
    }

    private static func mapBRDAction(_ action: String) -> AIActionType {
        switch action.lowercased() {
        case "createtask", "create_task":
            return .createTask
        case "updatetask", "update_task":
            return .updateTask
        case "deletetask", "delete_task":
            return .deleteTask
        case "createevent", "create_event":
            return .createEvent
        case "updateevent", "update_event":
            return .updateEvent
        case "deleteevent", "delete_event":
            return .deleteEvent
        case "suggesttime", "suggest_time":
            return .suggestTimeSlots
        case "prioritize":
            return .prioritizeTasks
        case "summarize":
            return .requestClarification // можно добавить отдельный тип если нужен
        default:
            return .showError
        }
    }

    private static func extractTitle(from action: String, payload: [String: Any]) -> String {
        // Извлечь title из payload или использовать action как fallback
        if let title = payload["title"] as? String, !title.isEmpty {
            return title
        }

        switch action.lowercased() {
        case "createtask", "create_task":
            return "Create Task"
        case "updatetask", "update_task":
            return "Update Task"
        case "deletetask", "delete_task":
            return "Delete Task"
        case "createevent", "create_event":
            return "Create Event"
        case "updateevent", "update_event":
            return "Update Event"
        case "deleteevent", "delete_event":
            return "Delete Event"
        case "suggesttime", "suggest_time":
            return "Find Time Slot"
        case "prioritize":
            return "Prioritize Tasks"
        default:
            return "AI Action"
        }
    }

    private static func extractDescription(from payload: [String: Any], actionType: AIActionType) -> String {
        // Build description from payload fields
        var parts: [String] = []

        if let title = payload["title"] as? String {
            parts.append(title)
        }

        if let priority = payload["priority"] as? Int {
            parts.append("Priority: \(priority)")
        }

        if let dueDate = payload["dueDate"] as? String {
            parts.append("Due: \(dueDate)")
        } else if let dueDate = payload["due_date"] as? String {
            parts.append("Due: \(dueDate)")
        }

        if let startTime = payload["startTime"] as? String {
            parts.append("Start: \(startTime)")
        } else if let startDate = payload["start_date"] as? String {
            parts.append("Start: \(startDate)")
        }

        if let duration = payload["duration"] as? Int {
            parts.append("\(duration) min")
        } else if let estimatedDuration = payload["estimated_duration"] as? Int {
            parts.append("\(estimatedDuration) min")
        }

        return parts.isEmpty ? actionType.displayName : parts.joined(separator: " • ")
    }

    // MARK: - Generate BRD-compliant JSON for LLM
    static func generateBRDSystemPrompt() -> String {
        return """
        You are Sekretar AI planning assistant. Analyze user input and respond with STRICT JSON matching this contract:

        {
          "action": "createTask|updateTask|deleteTask|createEvent|updateEvent|deleteEvent|suggestTime|prioritize|summarize",
          "payload": {
            // For createTask/updateTask:
            "title": "string (required)",
            "priority": 0-3 (0=low, 1=normal, 2=high, 3=urgent),
            "dueDate": "ISO8601 string (optional)",
            "estimatedDuration": minutes (optional),
            "notes": "string (optional)"

            // For createEvent/updateEvent:
            "title": "string (required)",
            "startDate": "ISO8601 string (required)",
            "endDate": "ISO8601 string (optional)",
            "isAllDay": boolean (optional),
            "location": "string (optional)"

            // For suggestTime:
            "taskTitle": "string",
            "duration": minutes,
            "deadline": "ISO8601 string (optional)",
            "preferredTime": "morning|afternoon|evening (optional)"
          },
          "meta": {
            "confidence": 0.0-1.0 (your confidence in parsing),
            "requiresConfirmation": true|false (true if missing critical info)
          }
        }

        Rules:
        - ALWAYS return valid JSON. NO markdown, NO code fences, NO explanations.
        - If input is unclear, set requiresConfirmation: true and use best guess for payload.
        - Support Russian and English.
        - Parse dates/times naturally ("завтра в 15:00", "tomorrow at 3pm", "через час" = now+1h, "через 30 минут" = now+30min).
        - Set confidence based on clarity of user input (0.9+ for clear, 0.5-0.7 for ambiguous).
        - Use ISO8601 format for dates: "2025-10-01T15:00:00Z" or "2025-10-01T15:00:00+03:00"
        - CURRENT TIME: {{CURRENT_TIME}} - use as reference for relative dates

        Examples:

        User: "Создай задачу купить молоко завтра"
        {
          "action": "createTask",
          "payload": {
            "title": "купить молоко",
            "dueDate": "2025-10-02T12:00:00+03:00",
            "priority": 1
          },
          "meta": {
            "confidence": 0.85,
            "requiresConfirmation": false
          }
        }

        User: "Запланируй встречу с командой послезавтра в 14:00"
        {
          "action": "createEvent",
          "payload": {
            "title": "встреча с командой",
            "startDate": "2025-10-03T14:00:00+03:00",
            "endDate": "2025-10-03T15:00:00+03:00"
          },
          "meta": {
            "confidence": 0.9,
            "requiresConfirmation": false
          }
        }

        User: "нужно сделать отчёт"
        {
          "action": "createTask",
          "payload": {
            "title": "сделать отчёт",
            "priority": 1
          },
          "meta": {
            "confidence": 0.7,
            "requiresConfirmation": true
          }
        }

        User: "Удали задачу купить молоко"
        {
          "action": "deleteTask",
          "payload": {
            "title": "купить молоко"
          },
          "meta": {
            "confidence": 0.9,
            "requiresConfirmation": true
          }
        }

        User: "Перенеси встречу с командой на послезавтра в 14:00"
        {
          "action": "updateEvent",
          "payload": {
            "title": "встреча с командой",
            "startDate": "2025-10-03T14:00:00+03:00",
            "endDate": "2025-10-03T15:00:00+03:00"
          },
          "meta": {
            "confidence": 0.8,
            "requiresConfirmation": true
          }
        }

        User: "Измени приоритет задачи отчёт на высокий"
        {
          "action": "updateTask",
          "payload": {
            "title": "отчёт",
            "priority": 2
          },
          "meta": {
            "confidence": 0.85,
            "requiresConfirmation": true
          }
        }
        """
    }
}