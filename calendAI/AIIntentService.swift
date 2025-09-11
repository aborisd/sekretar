import Foundation
import CoreData
import SwiftUI

// MARK: - AI Intent Service
@MainActor
final class AIIntentService: ObservableObject {
    static let shared = AIIntentService()
    
    @Published var isProcessing = false
    @Published var pendingAction: AIAction?
    @Published var showingPreview = false
    
    private let llmProvider: LLMProviderProtocol
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
         llmProvider: LLMProviderProtocol = AIProviderFactory.current()) {
        self.context = context
        self.llmProvider = llmProvider
    }
    
    // MARK: - Main Processing Method
    func processUserInput(_ input: String) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Step 1: Parse user intent
            let intent = try await llmProvider.detectIntent(input)
            
            // Step 2: Generate structured action based on intent
            let action = try await generateAction(for: intent, input: input)
            
            // Step 3: Validate the action
            let validationResult = try await validateAction(action)
            
            // Step 4: Show preview if action is valid
            if validationResult.isValid {
                pendingAction = action
                showingPreview = true
                
                // Log action for undo/redo
                try await logAIAction(action)
            } else {
                // Show error or ask for clarification
                let clarificationAction = AIAction(
                    type: .requestClarification,
                    title: "Need More Information",
                    description: validationResult.errorMessage ?? "Could you provide more details?",
                    confidence: 0.9,
                    requiresConfirmation: true,
                    payload: ["original_input": input]
                )
                pendingAction = clarificationAction
                showingPreview = true
            }
            
        } catch {
            print("Error processing user input: \(error)")
            let errorAction = AIAction(
                type: .showError,
                title: "Processing Error",
                description: "Sorry, I had trouble understanding that. Could you try rephrasing?",
                confidence: 1.0,
                requiresConfirmation: false,
                payload: ["error": error.localizedDescription]
            )
            pendingAction = errorAction
            showingPreview = true
        }
    }
    
    // MARK: - Action Execution
    func executeAction(_ action: AIAction) async throws {
        switch action.type {
        case .createTask:
            try await executeCreateTask(action)
        case .updateTask:
            try await executeUpdateTask(action)
        case .deleteTask:
            try await executeDeleteTask(action)
        case .createEvent:
            try await executeCreateEvent(action)
        case .updateEvent:
            try await executeUpdateEvent(action)
        case .deleteEvent:
            try await executeDeleteEvent(action)
        case .suggestTimeSlots:
            try await executeSuggestTimeSlots(action)
        case .prioritizeTasks:
            try await executePrioritizeTasks(action)
        case .requestClarification, .showError:
            // These don't require execution, just display
            break
        }
        
        // Track successful execution
        AnalyticsService.shared.track(.aiActionExecuted, properties: [
            "action_type": action.type.rawValue,
            "confidence": action.confidence,
            "required_confirmation": action.requiresConfirmation
        ])
    }
    
    // MARK: - Private Methods
    
    private func generateAction(for intent: UserIntent, input: String) async throws -> AIAction {
        switch intent {
        case .createTask:
            return try await generateCreateTaskAction(input: input)
        case .modifyTask:
            return try await generateModifyTaskAction(input: input)
        case .deleteTask:
            return try await generateDeleteTaskAction(input: input)
        case .scheduleTask:
            return try await generateScheduleTaskAction(input: input)
        case .requestSuggestion:
            return try await generateSuggestionAction(input: input)
        case .askQuestion:
            return try await generateQuestionAction(input: input)
        case .unknown:
            return AIAction(
                type: .requestClarification,
                title: "I didn't quite understand",
                description: "Could you be more specific about what you'd like me to help with?",
                confidence: 0.8,
                requiresConfirmation: true,
                payload: ["original_input": input]
            )
        }
    }
    
    private func generateCreateTaskAction(input: String) async throws -> AIAction {
        let analysis = try await llmProvider.analyzeTask(input)
        
        // Extract task title from input (simple approach)
        let title = extractTaskTitle(from: input)
        
        let payload: [String: Any] = [
            "title": title,
            "priority": analysis.suggestedPriority,
            "notes": input,
            "category": analysis.category,
            "estimated_duration": analysis.estimatedDuration,
            "suggested_tags": analysis.suggestedTags
        ]
        
        return AIAction(
            type: .createTask,
            title: "Create Task",
            description: "Create task: \"\(title)\" with priority \(analysis.suggestedPriority)",
            confidence: 0.85,
            requiresConfirmation: true,
            payload: payload
        )
    }
    
    private func generateModifyTaskAction(input: String) async throws -> AIAction {
        // For now, return a placeholder action
        // In a full implementation, this would find the task to modify
        return AIAction(
            type: .updateTask,
            title: "Modify Task",
            description: "I can help you modify a task. Which task would you like to change?",
            confidence: 0.7,
            requiresConfirmation: true,
            payload: ["input": input]
        )
    }
    
    private func generateDeleteTaskAction(input: String) async throws -> AIAction {
        return AIAction(
            type: .deleteTask,
            title: "Delete Task",
            description: "I can help you delete a task. Which task would you like to remove?",
            confidence: 0.7,
            requiresConfirmation: true,
            payload: ["input": input]
        )
    }
    
    private func generateScheduleTaskAction(input: String) async throws -> AIAction {
        return AIAction(
            type: .suggestTimeSlots,
            title: "Schedule Task",
            description: "Let me find the best time slots for your task.",
            confidence: 0.8,
            requiresConfirmation: false,
            payload: ["input": input]
        )
    }
    
    private func generateSuggestionAction(input: String) async throws -> AIAction {
        return AIAction(
            type: .suggestTimeSlots,
            title: "Productivity Suggestions",
            description: "I'll analyze your tasks and provide personalized suggestions.",
            confidence: 0.9,
            requiresConfirmation: false,
            payload: ["context": input]
        )
    }
    
    private func generateQuestionAction(input: String) async throws -> AIAction {
        let response = try await llmProvider.generateResponse(input)
        
        return AIAction(
            type: .requestClarification,
            title: "Answer",
            description: response,
            confidence: 0.8,
            requiresConfirmation: false,
            payload: ["question": input, "answer": response]
        )
    }
    
    private func validateAction(_ action: AIAction) async throws -> AIValidationResult {
        switch action.type {
        case .createTask:
            return validateCreateTaskAction(action)
        case .updateTask:
            return validateUpdateTaskAction(action)
        case .deleteTask:
            return validateDeleteTaskAction(action)
        case .createEvent:
            return validateCreateEventAction(action)
        case .updateEvent:
            return validateUpdateEventAction(action)
        case .deleteEvent:
            return validateDeleteEventAction(action)
        case .suggestTimeSlots, .prioritizeTasks, .requestClarification, .showError:
            return AIValidationResult(isValid: true, errorMessage: nil)
        }
    }
    
    private func validateCreateTaskAction(_ action: AIAction) -> AIValidationResult {
        guard let title = action.payload["title"] as? String, !title.isEmpty else {
            return AIValidationResult(isValid: false, errorMessage: "Task title is required")
        }
        
        if let priority = action.payload["priority"] as? Int, priority < 0 || priority > 3 {
            return AIValidationResult(isValid: false, errorMessage: "Priority must be between 0 and 3")
        }
        
        return AIValidationResult(isValid: true, errorMessage: nil)
    }
    
    private func validateUpdateTaskAction(_ action: AIAction) -> AIValidationResult {
        // Add validation logic for task updates
        return AIValidationResult(isValid: true, errorMessage: nil)
    }
    
    private func validateDeleteTaskAction(_ action: AIAction) -> AIValidationResult {
        // Add validation logic for task deletion
        return AIValidationResult(isValid: true, errorMessage: nil)
    }
    
    private func validateCreateEventAction(_ action: AIAction) -> AIValidationResult {
        // Add validation logic for event creation
        return AIValidationResult(isValid: true, errorMessage: nil)
    }
    
    private func validateUpdateEventAction(_ action: AIAction) -> AIValidationResult {
        // Add validation logic for event updates
        return AIValidationResult(isValid: true, errorMessage: nil)
    }
    
    private func validateDeleteEventAction(_ action: AIAction) -> AIValidationResult {
        // Add validation logic for event deletion
        return AIValidationResult(isValid: true, errorMessage: nil)
    }
    
    // MARK: - Action Execution Methods
    
    private func executeCreateTask(_ action: AIAction) async throws {
        guard let title = action.payload["title"] as? String else {
            throw AIError.missingRequiredField("title")
        }
        
        await context.perform {
            let task = TaskEntity(context: self.context)
            task.id = UUID()
            task.title = title
            task.notes = action.payload["notes"] as? String
            task.priority = Int16(action.payload["priority"] as? Int ?? 1)
            task.isCompleted = false
            task.createdAt = Date()
            task.updatedAt = Date()
            
            if let duration = action.payload["estimated_duration"] as? TimeInterval {
                // Could set due date based on estimated duration
                task.dueDate = Date().addingTimeInterval(duration * 2) // Give 2x the estimated time
            }
            
            try? self.context.save()
        }
    }
    
    private func executeUpdateTask(_ action: AIAction) async throws {
        // Implementation for task updates
        // This would find the task by ID and update its properties
    }
    
    private func executeDeleteTask(_ action: AIAction) async throws {
        // Implementation for task deletion
        // This would find the task by ID and delete it
    }
    
    private func executeCreateEvent(_ action: AIAction) async throws {
        // Implementation for event creation
    }
    
    private func executeUpdateEvent(_ action: AIAction) async throws {
        // Implementation for event updates
    }
    
    private func executeDeleteEvent(_ action: AIAction) async throws {
        // Implementation for event deletion
    }
    
    private func executeSuggestTimeSlots(_ action: AIAction) async throws {
        // Implementation for time slot suggestions
        let tasks = try await fetchCurrentTasks()
        let optimization = try await llmProvider.optimizeSchedule(tasks)
        
        // Update the action with suggestions
        var updatedPayload = action.payload
        updatedPayload["suggestions"] = optimization.optimizedTasks
        updatedPayload["reasoning"] = optimization.reasoning
        updatedPayload["productivity_score"] = optimization.productivityScore
    }
    
    private func executePrioritizeTasks(_ action: AIAction) async throws {
        // Implementation for task prioritization
    }
    
    // MARK: - Helper Methods
    
    private func extractTaskTitle(from input: String) -> String {
        let lowercased = input.lowercased()
        
        // Remove common prefixes
        let prefixes = ["create a task to ", "add a task to ", "i need to ", "create task ", "add task "]
        for prefix in prefixes {
            if lowercased.hasPrefix(prefix) {
                return String(input.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // If no prefix found, use the whole input but limit length
        let maxLength = 50
        if input.count > maxLength {
            return String(input.prefix(maxLength)) + "..."
        }
        
        return input.trimmingCharacters(in: .whitespaces)
    }
    
    private func fetchCurrentTasks() async throws -> [TaskSummary] {
        return try await context.perform {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isCompleted == NO")
            request.sortDescriptors = [NSSortDescriptor(key: "priority", ascending: false)]
            
            let tasks = try self.context.fetch(request)
            
            return tasks.map { task in
                TaskSummary(
                    id: task.id ?? UUID(),
                    title: task.title ?? "Untitled Task",
                    priority: Int(task.priority),
                    dueDate: task.dueDate,
                    estimatedDuration: 3600, // Default 1 hour
                    isCompleted: task.isCompleted
                )
            }
        }
    }
    
    private func logAIAction(_ action: AIAction) async throws {
        await context.perform {
            let log = AIActionLogEntity(context: self.context)
            log.id = UUID()
            log.action = action.type.rawValue
            log.payload = self.encodePayload(action.payload)
            log.createdAt = Date()
            log.confidence = Float(action.confidence)
            log.requiresConfirmation = action.requiresConfirmation
            log.isExecuted = false
            
            try? self.context.save()
        }
    }
    
    private func encodePayload(_ payload: [String: Any]) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
    
    // MARK: - Public Action Management
    
    func confirmPendingAction() async {
        guard let action = pendingAction else { return }
        
        do {
            try await executeAction(action)
            pendingAction = nil
            showingPreview = false
        } catch {
            print("Error executing action: \(error)")
            // Show error to user
        }
    }
    
    func cancelPendingAction() {
        pendingAction = nil
        showingPreview = false
    }
}

// MARK: - Data Models

struct AIAction {
    let type: AIActionType
    let title: String
    let description: String
    let confidence: Double
    let requiresConfirmation: Bool
    var payload: [String: Any]
}

enum AIActionType: String, CaseIterable {
    case createTask = "create_task"
    case updateTask = "update_task" 
    case deleteTask = "delete_task"
    case createEvent = "create_event"
    case updateEvent = "update_event"
    case deleteEvent = "delete_event"
    case suggestTimeSlots = "suggest_time_slots"
    case prioritizeTasks = "prioritize_tasks"
    case requestClarification = "request_clarification"
    case showError = "show_error"
    
    var displayName: String {
        switch self {
        case .createTask: return "Create Task"
        case .updateTask: return "Update Task"
        case .deleteTask: return "Delete Task"
        case .createEvent: return "Create Event"
        case .updateEvent: return "Update Event"
        case .deleteEvent: return "Delete Event"
        case .suggestTimeSlots: return "Suggest Time Slots"
        case .prioritizeTasks: return "Prioritize Tasks"
        case .requestClarification: return "Request Clarification"
        case .showError: return "Show Error"
        }
    }
    
    var icon: String {
        switch self {
        case .createTask: return "plus.circle"
        case .updateTask: return "pencil.circle"
        case .deleteTask: return "trash.circle"
        case .createEvent: return "calendar.badge.plus"
        case .updateEvent: return "calendar.badge.gearshape"
        case .deleteEvent: return "calendar.badge.minus"
        case .suggestTimeSlots: return "clock.badge.checkmark"
        case .prioritizeTasks: return "list.number"
        case .requestClarification: return "questionmark.circle"
        case .showError: return "exclamationmark.triangle"
        }
    }
}

struct AIValidationResult {
    let isValid: Bool
    let errorMessage: String?
}

enum AIError: LocalizedError {
    case missingRequiredField(String)
    case invalidData(String)
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        }
    }
}

// MARK: - Analytics Extension
extension AnalyticsEvent {
    static let aiActionExecuted = AnalyticsEvent(rawValue: "ai_action_executed")!
}
