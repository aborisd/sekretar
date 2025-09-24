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
    @Published var lastResultToast: String?
    @Published var lastOpenLink: OpenLink?
    
    private let llmProvider: LLMProviderProtocol
    private let context: NSManagedObjectContext
    private var lastAppliedEventIDs: [UUID] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
         llmProvider: LLMProviderProtocol = AIProviderFactory.current()) {
        self.context = context
        self.llmProvider = llmProvider
    }
    
    // MARK: - Main Processing Method
    func processUserInput(_ input: String) async {
        if Task.isCancelled { return }
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try Task.checkCancellation()
            // Step 1: Heuristic intent detection (RU/EN) before LLM
            if let forced = forcedIntent(from: input) {
                // Generate action via local/JSON helpers without relying on free-form chat
                let action = try await generateAction(for: forced, input: input)
                let validationResult = try await validateAction(action)
                if validationResult.isValid {
                    if shouldAutoApply(action: action, originalInput: input, forced: true) {
                        try await executeAction(action)
                        try await logAIAction(action)
                        emitToast(successToast(for: action))
                        pendingAction = nil
                        showingPreview = false
                    } else {
                        pendingAction = action
                        showingPreview = true
                        try await logAIAction(action)
                    }
                } else {
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
                return
            }

            // Step 1 (fallback): Parse user intent via LLM provider
            try Task.checkCancellation()
            let intent = try await llmProvider.detectIntent(input)
            
            // Step 2: Generate structured action based on intent
            try Task.checkCancellation()
            let action = try await generateAction(for: intent, input: input)
            
            // Step 3: Validate the action
            try Task.checkCancellation()
            let validationResult = try await validateAction(action)
            
            // Step 4: Show preview if action is valid
            if validationResult.isValid {
                if shouldAutoApply(action: action, originalInput: input, forced: false) {
                    try await executeAction(action)
                    try await logAIAction(action)
                    emitToast(successToast(for: action))
                    pendingAction = nil
                    showingPreview = false
                } else {
                    pendingAction = action
                    showingPreview = true
                    // Log action for undo/redo
                    try await logAIAction(action)
                }
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
            
        } catch is CancellationError {
            // silently ignore
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

    // MARK: - Heuristics (deterministic router)
    private func forcedIntent(from input: String) -> UserIntent? {
        let s = input.lowercased()
        func any(_ arr: [String]) -> Bool { arr.contains { s.contains($0) } }
        // If phrase mentions meeting/calendar explicitly → scheduling
        if any(["встреч", "в календар"]) { return .scheduleTask }
        // Create task when verbs + (task noun OR generic command with time window)
        if any(["создай","добавь","создать","добавить","поставь","занеси"]) {
            if any(["задач","task"]) { return .createTask }
            // если есть окно времени и нет слова встречи — считаем задачей
            if hasTimeRangeOrPoint(in: s) && !any(["встреч"]) { return .createTask }
        }
        // Time range present? If не указана задача/встреча, считаем это планированием
        if hasTimeRangeOrPoint(in: s) { return .scheduleTask }
        // Scheduling verbs
        if any(["запланируй","подбери","найди","распиши","назначь","schedule"]) { return .scheduleTask }
        return nil
    }

    private func hasTimeRangeOrPoint(in s: String) -> Bool {
        // quick check for digits or common words
        if s.range(of: #"\b([01]?\d|2[0-3])([:.][0-5]\d)?\b"#, options: .regularExpression) != nil { return true }
        if ["час", "часа", "пол", "три", "четыр", "пять", "шесть", "семь", "восемь", "девять", "десять", "одиннадцать", "двенадцать"].contains(where: { s.contains($0) }) { return true }
        if s.contains("с ") && s.contains(" до ") { return true }
        return false
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
            // If suggestions already present in payload, apply them; else compute
            if let suggestions = action.payload["suggestions"] as? [[String: Any]], !suggestions.isEmpty {
                try await applyScheduleSuggestions(suggestions, actionPayload: action.payload)
            } else {
                try await executeSuggestTimeSlots(action)
            }
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
            // Если пользователь явно создаёт встречу/событие — сформируем событие, иначе подберём слоты
            let lower = input.lowercased()
            if ["встреч", "митинг", "meeting", "событ", "event", "calendar"].contains(where: { lower.contains($0) }) {
                return try await generateCreateEventAction(input: input)
            } else {
                return try await generateScheduleTaskAction(input: input)
            }
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
        // Try to extract schedule from phrase (via parseEvent to reuse NL parsing)
        var startDate: Date? = nil
        var endDate: Date? = nil
        do {
            let draft = try await llmProvider.parseEvent(input)
            // Consider it a schedule only if duration >= 15m
            if draft.end.timeIntervalSince(draft.start) >= 15 * 60 {
                startDate = draft.start; endDate = draft.end
            }
        } catch {}

        // Extract task title from input (simple approach)
        let title = extractTaskTitle(from: input)
        
        let payload: [String: Any] = [
            "title": title,
            "priority": analysis.suggestedPriority,
            "notes": input,
            "category": analysis.category,
            "estimated_duration": analysis.estimatedDuration,
            "suggested_tags": analysis.suggestedTags,
            "start": startDate as Any,
            "end": endDate as Any
        ]
        
        return AIAction(
            type: .createTask,
            title: L10n.AIActionText.createTaskTitle,
            description: startDate != nil
                ? localized("Создать задачу и забронировать время", en: "Create task and schedule time window")
                : localized("Создать задачу \"\(title)\" с приоритетом \(analysis.suggestedPriority)", en: "Create task \"\(title)\" with priority \(analysis.suggestedPriority)"),
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
            title: L10n.AIActionText.updateTaskTitle,
            description: localized("Я помогу изменить задачу. Какую именно нужно обновить?", en: "I can help you modify a task. Which task would you like to change?"),
            confidence: 0.7,
            requiresConfirmation: true,
            payload: ["input": input]
        )
    }
    
    private func generateDeleteTaskAction(input: String) async throws -> AIAction {
        return AIAction(
            type: .deleteTask,
            title: L10n.AIActionText.deleteTaskTitle,
            description: localized("Какую задачу удалить?", en: "Which task would you like to remove?"),
            confidence: 0.7,
            requiresConfirmation: true,
            payload: ["input": input]
        )
    }
    
    private func generateScheduleTaskAction(input: String) async throws -> AIAction {
        return AIAction(
            type: .suggestTimeSlots,
            title: L10n.AIActionText.scheduleTaskTitle,
            description: localized("Подберу подходящие окна в расписании.", en: "Let me find the best time slots for your task."),
            confidence: 0.8,
            requiresConfirmation: false,
            payload: ["input": input]
        )
    }
    
    private func generateSuggestionAction(input: String) async throws -> AIAction {
        return AIAction(
            type: .suggestTimeSlots,
            title: L10n.AIActionText.scheduleTaskTitle,
            description: localized("Проанализирую задачи и предложу улучшения.", en: "I'll analyze your tasks and provide personalized suggestions."),
            confidence: 0.9,
            requiresConfirmation: false,
            payload: ["context": input]
        )
    }

    private func generateCreateEventAction(input: String) async throws -> AIAction {
        var draft = try await llmProvider.parseEvent(input)
        draft = await normalizeEventDraft(draft, originalInput: input)

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Событие" : draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        var payload: [String: Any] = [
            "title": title,
            "start": draft.start,
            "end": draft.end,
            "is_all_day": draft.isAllDay
        ]
        if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["notes"] = input
        }

        let descriptionFormatter = DateFormatter()
        descriptionFormatter.locale = Locale(identifier: "ru_RU")
        descriptionFormatter.dateFormat = draft.isAllDay ? "d MMMM" : "d MMMM, HH:mm"
        let timeString = descriptionFormatter.string(from: draft.start)

        return AIAction(
            type: .createEvent,
            title: L10n.AIActionText.createEventTitle,
            description: draft.isAllDay
                ? localized("\(title) — весь день \(timeString)", en: "\(title) — all-day on \(timeString)")
                : localized("\(title) — \(timeString)", en: "\(title) — \(timeString)"),
            confidence: 0.85,
            requiresConfirmation: true,
            payload: payload
        )
    }
    
    private func generateQuestionAction(input: String) async throws -> AIAction {
        let response = try await llmProvider.generateResponse(input)
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let concise: String
        if trimmed.count > 320 {
            if let lastSentenceEnd = trimmed.prefix(320).lastIndex(of: Character(".")) {
                let candidate = trimmed[..<trimmed.index(after: lastSentenceEnd)]
                concise = candidate.trimmingCharacters(in: .whitespacesAndNewlines) + " …"
            } else {
                concise = trimmed.prefix(320).trimmingCharacters(in: .whitespacesAndNewlines) + " …"
            }
        } else {
            concise = trimmed
        }

        return AIAction(
            type: .requestClarification,
            title: L10n.AIActionText.answerTitle,
            description: concise,
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
        var due: Date? = action.payload["start"] as? Date
        await context.perform {
            let task = TaskEntity(context: self.context)
            task.id = UUID()
            task.title = title
            task.notes = action.payload["notes"] as? String
            task.priority = Int16(action.payload["priority"] as? Int ?? 1)
            task.isCompleted = false
            task.createdAt = Date()
            task.updatedAt = Date()
            // Если распознали окно — используем как dueDate, иначе можно поставить nil
            task.dueDate = due
            
            try? self.context.save()
        }
        // Предложим открыть список задач на соответствующую дату
        self.lastOpenLink = OpenLink(tab: .tasks, date: due)

        // If schedule is present, create a calendar event, too
        if let start = action.payload["start"] as? Date,
           let end = action.payload["end"] as? Date,
           end > start {
            await context.perform {
                let ev = EventEntity(context: self.context)
                ev.id = UUID()
                ev.title = title
                ev.startDate = start
                ev.endDate = end
                ev.isAllDay = false
                ev.notes = "Создано при добавлении задачи"
                try? self.context.save()
            }
            if let created = try? await fetchEvent(byTitle: title, start: start, end: end) {
                try? await EventKitService(context: context).syncToEventKit(created)
            }
            self.lastOpenLink = OpenLink(tab: .calendar, date: start)
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
        guard let title = action.payload["title"] as? String, !title.isEmpty else {
            throw AIError.missingRequiredField("title")
        }
        let start = action.payload["start"] as? Date ?? Date().addingTimeInterval(3600)
        let end = action.payload["end"] as? Date ?? start.addingTimeInterval(3600)
        let isAllDay = action.payload["is_all_day"] as? Bool ?? false

        var created: EventEntity?
        await context.perform {
            let ev = EventEntity(context: self.context)
            ev.id = UUID()
            ev.title = title
            ev.startDate = start
            ev.endDate = end
            ev.isAllDay = isAllDay
            ev.notes = action.payload["notes"] as? String
            try? self.context.save()
            created = ev
        }
        if let created { try? await EventKitService(context: context).syncToEventKit(created) }
        self.lastOpenLink = OpenLink(tab: .calendar, date: start)
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
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let suggestions: [[String: Any]] = optimization.optimizedTasks.map { item in
            [
                "task_id": item.taskId.uuidString,
                "suggested_start": df.string(from: item.suggestedStartTime),
                "suggested_duration_sec": Int(item.suggestedDuration),
                "confidence": item.confidence
            ]
        }
        updatedPayload["suggestions"] = suggestions
        updatedPayload["reasoning"] = optimization.reasoning
        updatedPayload["productivity_score"] = optimization.productivityScore

        let title = "Suggested Time Slots"
        let desc = suggestions.isEmpty ? "No suitable free slots found." : "Found \(suggestions.count) suggestion(s). Review and confirm to apply."
        let preview = AIAction(
            type: .suggestTimeSlots,
            title: title,
            description: desc,
            confidence: 0.85,
            requiresConfirmation: true,
            payload: updatedPayload
        )
        pendingAction = preview
        showingPreview = true
    }

    private func applyScheduleSuggestions(_ suggestions: [[String: Any]], actionPayload: [String: Any]) async throws {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Create events for each suggestion
        var createdEventIDs: [UUID] = []
        for item in suggestions {
            guard let idStr = item["task_id"] as? String,
                  let taskId = UUID(uuidString: idStr),
                  let startStr = item["suggested_start"] as? String,
                  let startDate = df.date(from: startStr) ?? ISO8601DateFormatter().date(from: startStr)
            else { continue }

            let durationSec = (item["suggested_duration_sec"] as? Int) ?? 3600
            let endDate = startDate.addingTimeInterval(TimeInterval(durationSec))

            // Fetch task title if available
            let title = await fetchTaskTitle(by: taskId) ?? "Запланированная задача"

            await context.perform {
                let event = EventEntity(context: self.context)
                let eid = UUID()
                event.id = eid
                event.title = title
                event.startDate = startDate
                event.endDate = endDate
                event.isAllDay = false
                event.notes = "Создано ИИ (расписание)"
                try? self.context.save()
                createdEventIDs.append(eid)
            }

            // Try to sync with system calendar (best-effort)
            let svc = EventKitService(context: context)
            if let created = try? await fetchEvent(byTitle: title, start: startDate, end: endDate) {
                try? await svc.syncToEventKit(created)
            }
        }

        // After applying, clear preview
        pendingAction = nil
        showingPreview = false

        // Save applied ids for undo
        lastAppliedEventIDs = createdEventIDs

        // Log action
        let payload: [String: Any] = [
            "action": "apply_schedule",
            "event_ids": createdEventIDs.map { $0.uuidString },
            "reasoning": actionPayload["reasoning"] ?? "",
            "productivity_score": actionPayload["productivity_score"] ?? 0
        ]
        try? await logAIAction(AIAction(type: .createEvent, title: "Apply Schedule", description: "Events created", confidence: 1.0, requiresConfirmation: false, payload: payload))
    }

    // Simple undo for the last applied schedule
    func undoLastAppliedSchedule() async {
        guard !lastAppliedEventIDs.isEmpty else { return }
        let ids = lastAppliedEventIDs
        lastAppliedEventIDs.removeAll()
        let svc = EventKitService(context: context)
        await context.perform {
            for id in ids {
                let fr: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                fr.fetchLimit = 1
                fr.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                if let ev = try? self.context.fetch(fr).first {
                    // Try delete from EventKit if linked
                    if let ekid = ev.eventKitId { Task { try? await svc.deleteFromEventKit(eventKitId: ekid) } }
                    self.context.delete(ev)
                }
            }
            try? self.context.save()
        }
    }

    private func fetchTaskTitle(by id: UUID) async -> String? {
        return await context.perform {
            let fr: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            fr.fetchLimit = 1
            fr.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let task = try? self.context.fetch(fr).first {
                return task.title
            }
            return nil
        }
    }

    private func fetchEvent(byTitle title: String, start: Date, end: Date) async throws -> EventEntity? {
        return try await context.perform {
            let fr: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
            fr.fetchLimit = 1
            fr.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "title == %@", title),
                NSPredicate(format: "startDate == %@", start as CVarArg),
                NSPredicate(format: "endDate == %@", end as CVarArg)
            ])
            return try self.context.fetch(fr).first
        }
    }
    
    private func executePrioritizeTasks(_ action: AIAction) async throws {
        // Implementation for task prioritization
    }
    
    // MARK: - Helper Methods
    
    private func extractTaskTitle(from input: String) -> String {
        // Удаляем служебные слова, время и команды, чтобы не дублировать фразу целиком
        var s = input
        let verbs = [
            "создай","создать","добавь","добавить","поставь","занеси",
            "create a task to ","add a task to ","i need to ","create task ","add task "
        ]
        for v in verbs { s = s.replacingOccurrences(of: v, with: " ", options: .caseInsensitive) }
        // Слова "задачу/task"
        ["задачу","задача","task"].forEach { s = s.replacingOccurrences(of: $0, with: " ", options: .caseInsensitive) }
        // Удаляем указания времени (аналогичные эвенты)
        s = s.replacingOccurrences(of: #"\bв\s*([01]?\d|2[0-3])([:\\.][0-5]\d)?\b"#, with: " ", options: .regularExpression)
        ["сегодня","завтра","послезавтра","today","tomorrow","day after","утра","вечера","дня","ночи"].forEach { s = s.replacingOccurrences(of: $0, with: " ", options: .caseInsensitive) }
        s = s.replacingOccurrences(of: #"с\s*([01]?\d|2[0-3])([:\\.][0-5]\d)?\s*до\s*([01]?\d|2[0-3])([:\\.][0-5]\d)?"#, with: " ", options: .regularExpression)

        let cleaned = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return "Задача" }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }

    private func normalizeEventDraft(_ draft: EventDraft, originalInput: String) async -> EventDraft {
        var adjusted = draft
        let now = Date()
        let reference = Date(timeIntervalSince1970: 946684800) // 1 Jan 2000

        if adjusted.start < reference || adjusted.start.timeIntervalSince1970 <= 0 {
            if let fallback = try? await EnhancedLLMProvider.shared.parseEvent(originalInput) {
                adjusted = fallback
            } else if let heuristic = heuristicEvent(from: originalInput, base: now) {
                adjusted = heuristic
            }
        }

        // Гарантируем длительность хотя бы 30 минут
        if adjusted.end <= adjusted.start {
            let end = adjusted.start.addingTimeInterval(1800)
            adjusted = EventDraft(title: adjusted.title, start: adjusted.start, end: end, isAllDay: adjusted.isAllDay)
        }

        let trimmed = adjusted.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            let fallbackTitle = extractTaskTitle(from: originalInput)
            adjusted = EventDraft(title: fallbackTitle, start: adjusted.start, end: adjusted.end, isAllDay: adjusted.isAllDay)
        }

        if let heur = heuristicEvent(from: originalInput, base: Date()) {
            let durationCandidate = max(adjusted.end.timeIntervalSince(adjusted.start), heur.end.timeIntervalSince(heur.start))
            let duration = max(durationCandidate, heur.isAllDay ? 86400 : 1800)
            if heur.isAllDay {
                let startDay = Calendar.current.startOfDay(for: heur.start)
                let endDay = Calendar.current.date(byAdding: .day, value: 1, to: startDay) ?? heur.end
                adjusted = EventDraft(title: adjusted.title, start: startDay, end: endDay, isAllDay: true)
            } else {
                let end = heur.start.addingTimeInterval(duration)
                adjusted = EventDraft(title: adjusted.title, start: heur.start, end: end, isAllDay: false)
            }
        }

        return adjusted
    }

    private func heuristicEvent(from input: String, base: Date) -> EventDraft? {
        let lower = input.lowercased()
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: base)
        if lower.contains("завтра") || lower.contains("tomorrow") {
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        } else if lower.contains("послезавтра") || lower.contains("day after") {
            day = calendar.date(byAdding: .day, value: 2, to: day) ?? day
        }

        let timePattern = try? NSRegularExpression(pattern: "(?:(?:в|at)\\s*)?([01]?\\d|2[0-3])[:\\.]?([0-5]\\d)?", options: [.caseInsensitive])
        let range = NSRange(lower.startIndex..<lower.endIndex, in: lower)
        guard let match = timePattern?.firstMatch(in: lower, options: [], range: range),
              let hourRange = Range(match.range(at: 1), in: lower) else {
            return nil
        }

        var hour = Int(lower[hourRange]) ?? 0
        var minute = 0
        if let minuteRange = Range(match.range(at: 2), in: lower) {
            minute = Int(lower[minuteRange]) ?? 0
        }

        if lower.contains("вечера") || lower.contains("pm") || lower.contains("дня") {
            if hour < 12 { hour += 12 }
        }
        if lower.contains("утра") && hour == 12 { hour = 0 }

        guard let start = calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: day) else {
            return nil
        }

        let end = start.addingTimeInterval(3600)
        let title = extractTaskTitle(from: input)
        return EventDraft(title: title, start: start, end: end, isAllDay: false)
    }

    private var isRussianLocale: Bool {
        if let stored = UserDefaults.standard.string(forKey: "app_language") {
            return stored.lowercased().hasPrefix("ru")
        }
        if let languageCode = Locale.preferredLanguages.first {
            return languageCode.lowercased().hasPrefix("ru")
        }
        return Locale.current.identifier.lowercased().hasPrefix("ru")
    }

    private func localized(_ ru: String, en: String) -> String {
        isRussianLocale ? ru : en
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
            // Avoid CoreData scalar type mismatches across model changes: store confidence inside payload only
            log.requiresConfirmation = action.requiresConfirmation
            log.isExecuted = false
            
            try? self.context.save()
        }
    }

    // MARK: - Auto-apply helpers
    private func shouldAutoApply(action: AIAction, originalInput: String, forced: Bool) -> Bool {
        guard FeatureFlags.shared.autoApplyEnabled else { return false }
        switch action.type {
        case .createTask:
            // Простое название + нет явных предупреждений
            return forced || action.confidence >= 0.8
        case .createEvent:
            // Есть валидные даты
            if action.payload["start"] is Date, action.payload["end"] is Date {
                return forced || action.confidence >= 0.8
            }
            return false
        default:
            return false
        }
    }

    private func successToast(for action: AIAction) -> String {
        switch action.type {
        case .createTask:
            let title = (action.payload["title"] as? String) ?? "Задача"
            return L10n.AIToast.taskCreated(title)
        case .createEvent:
            let title = (action.payload["title"] as? String) ?? "Событие"
            if let start = action.payload["start"] as? Date {
                let time = start.formatted(date: .abbreviated, time: .shortened)
                return L10n.AIToast.eventCreated(title, time: time)
            }
            return L10n.AIToast.eventCreated(title, time: nil)
        case .suggestTimeSlots:
            return L10n.AIToast.slots
        default:
            return L10n.AIToast.default
        }
    }

    private func emitToast(_ text: String) {
        lastResultToast = text
        // сбрасываем на следующем тике, чтобы не трогать View прямо во время обновления
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.lastResultToast = nil
        }
    }
    
    private func encodePayload(_ payload: [String: Any]) -> String {
        // Преобразуем в JSON‑дружелюбные типы (Date/UUID/Dict/Array → строковые представления)
        func makeJSONSafe(_ any: Any) -> Any {
            switch any {
            case let d as Date:
                let df = ISO8601DateFormatter(); df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return df.string(from: d)
            case let u as UUID:
                return u.uuidString
            case let num as NSNumber:
                return num
            case let s as String:
                return s
            case let b as Bool:
                return b
            case is NSNull:
                return NSNull()
            case let data as Data:
                return data.base64EncodedString()
            case let arr as [Any]:
                return arr.map { makeJSONSafe($0) }
            case let dict as [String: Any]:
                var out: [String: Any] = [:]
                for (k, v) in dict { out[k] = makeJSONSafe(v) }
                return out
            default:
                return String(describing: any)
            }
        }
        let safe = payload.mapValues { makeJSONSafe($0) }
        do {
            let data = try JSONSerialization.data(withJSONObject: safe, options: [])
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
    
    // MARK: - Public Action Management
    
    func confirmPendingAction() async {
        guard let action = pendingAction else { return }
        
        do {
            isProcessing = true
            try await executeAction(action)
            pendingAction = nil
            showingPreview = false
            isProcessing = false
        } catch {
            print("Error executing action: \(error)")
            // Show error to user
            isProcessing = false
        }
    }
    
    func cancelPendingAction() {
        pendingAction = nil
        showingPreview = false
    }
}

// MARK: - Data Models

struct AIAction: Identifiable {
    let id = UUID()
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

// MARK: - Analytics (no extension needed; case is defined in AnalyticsEvent)
