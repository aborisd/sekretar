import Foundation

// MARK: - Enhanced LLM Provider Protocol
protocol LLMProviderProtocol {
    func generateResponse(_ prompt: String) async throws -> String
    func analyzeTask(_ taskDescription: String) async throws -> TaskAnalysis
    func generateSmartSuggestions(_ context: String) async throws -> [SmartSuggestion]
    func optimizeSchedule(_ tasks: [TaskSummary]) async throws -> ScheduleOptimization
    func detectIntent(_ input: String) async throws -> UserIntent
    func parseEvent(_ description: String) async throws -> EventDraft
}

// MARK: - Data Models
struct TaskAnalysis {
    let suggestedPriority: Int
    let estimatedDuration: TimeInterval
    let suggestedTags: [String]
    let potentialSubtasks: [String]
    let category: String
    let complexity: TaskComplexity
}

struct SmartSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let description: String
    let confidence: Double // 0.0 to 1.0
    let actionable: Bool
}

enum SuggestionType: String, CaseIterable {
    case taskBreakdown = "task_breakdown"
    case timeOptimization = "time_optimization" 
    case priorityAdjustment = "priority_adjustment"
    case resourceAllocation = "resource_allocation"
    case scheduleConflict = "schedule_conflict"
    case productivity = "productivity"
    
    var displayName: String {
        switch self {
        case .taskBreakdown: return "Task Breakdown"
        case .timeOptimization: return "Time Optimization"
        case .priorityAdjustment: return "Priority Adjustment"
        case .resourceAllocation: return "Resource Allocation"
        case .scheduleConflict: return "Schedule Conflict"
        case .productivity: return "Productivity"
        }
    }
    
    var icon: String {
        switch self {
        case .taskBreakdown: return "list.bullet.rectangle"
        case .timeOptimization: return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .priorityAdjustment: return "slider.horizontal.3"
        case .resourceAllocation: return "person.2.fill"
        case .scheduleConflict: return "exclamationmark.triangle.fill"
        case .productivity: return "chart.line.uptrend.xyaxis"
        }
    }
}

enum TaskComplexity: String, CaseIterable {
    case simple = "simple"
    case moderate = "moderate"
    case complex = "complex"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .simple: return "Simple"
        case .moderate: return "Moderate"
        case .complex: return "Complex"
        case .expert: return "Expert"
        }
    }
    
    var estimatedDurationMultiplier: Double {
        switch self {
        case .simple: return 1.0
        case .moderate: return 1.5
        case .complex: return 2.5
        case .expert: return 4.0
        }
    }
}

struct TaskSummary {
    let id: UUID
    let title: String
    let priority: Int
    let dueDate: Date?
    let estimatedDuration: TimeInterval
    let isCompleted: Bool
}

struct ScheduleOptimization {
    let optimizedTasks: [OptimizedTask]
    let reasoning: String
    let productivityScore: Double
    let suggestions: [SmartSuggestion]
}

struct OptimizedTask {
    let taskId: UUID
    let suggestedStartTime: Date
    let suggestedDuration: TimeInterval
    let confidence: Double
}

// Event draft extracted from natural language
struct EventDraft {
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
}

enum UserIntent: String, CaseIterable {
    case createTask = "create_task"
    case modifyTask = "modify_task"
    case deleteTask = "delete_task"
    case scheduleTask = "schedule_task"
    case askQuestion = "ask_question"
    case requestSuggestion = "request_suggestion"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .createTask: return "Create Task"
        case .modifyTask: return "Modify Task"
        case .deleteTask: return "Delete Task"
        case .scheduleTask: return "Schedule Task"
        case .askQuestion: return "Ask Question"
        case .requestSuggestion: return "Request Suggestion"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Enhanced LLM Provider
final class EnhancedLLMProvider: LLMProviderProtocol {
    static let shared = EnhancedLLMProvider()
    
    // Configuration
    private let systemPrompt = """
        You are Sekretar, an intelligent personal assistant that helps users manage their tasks and schedule efficiently.
        
        Key capabilities:
        - Analyze tasks and suggest priorities, durations, and breakdowns
        - Optimize schedules for maximum productivity
        - Detect scheduling conflicts and suggest resolutions
        - Provide contextual suggestions based on user patterns
        - Communicate clearly and concisely in English
        
        Always respond in a helpful, professional, and encouraging manner.
        Focus on actionable insights that improve the user's productivity and well-being.
        """
    
    private init() {}
    
    func generateResponse(_ prompt: String) async throws -> String {
        // Smart response generation based on context (без искусственной задержки)
        
        let intent = try await detectIntent(prompt)
        
        switch intent {
        case .createTask:
            return "I'd be happy to help you create a new task! Could you provide more details about what needs to be done and when you'd like to complete it?"
        case .modifyTask:
            return "I can help you modify your task. What changes would you like to make? You can adjust the priority, due date, or add additional details."
        case .deleteTask:
            return "I understand you want to remove a task. Which task would you like to delete? I can help you find it in your list."
        case .scheduleTask:
            return "Let me help you find the perfect time for this task. I'll consider your existing schedule and productivity patterns to suggest optimal timing."
        case .requestSuggestion:
            return "I'd love to provide some personalized suggestions! Let me analyze your current tasks and schedule to recommend improvements."
        case .askQuestion:
            return "I'm here to help answer your questions about task management, scheduling, or productivity. What would you like to know?"
        case .unknown:
            return "I understand you're looking for assistance. Could you provide more details about what you'd like to accomplish? I can help with creating tasks, managing your schedule, or providing productivity tips."
        }
    }
    
    func analyzeTask(_ taskDescription: String) async throws -> TaskAnalysis {
        // убрана искусственная задержка
        
        let words = taskDescription.split(separator: " ")
        let lowercaseTask = taskDescription.lowercased()
        
        // Enhanced keyword-based analysis
        var priority = 1
        var category = "General"
        var complexity = TaskComplexity.simple
        var tags: [String] = []
        
        // Priority detection with English keywords
        if lowercaseTask.contains("urgent") || lowercaseTask.contains("asap") || lowercaseTask.contains("critical") || lowercaseTask.contains("emergency") {
            priority = 3
        } else if lowercaseTask.contains("important") || lowercaseTask.contains("soon") || lowercaseTask.contains("high priority") {
            priority = 2
        }
        
        // Category detection
        if lowercaseTask.contains("work") || lowercaseTask.contains("office") || lowercaseTask.contains("meeting") || lowercaseTask.contains("project") {
            category = "Work"
            tags.append("work")
        } else if lowercaseTask.contains("personal") || lowercaseTask.contains("home") || lowercaseTask.contains("family") {
            category = "Personal"
            tags.append("personal")
        } else if lowercaseTask.contains("health") || lowercaseTask.contains("exercise") || lowercaseTask.contains("doctor") || lowercaseTask.contains("fitness") {
            category = "Health"
            tags.append("health")
        } else if lowercaseTask.contains("shopping") || lowercaseTask.contains("buy") || lowercaseTask.contains("purchase") {
            category = "Shopping"
            tags.append("shopping")
        }
        
        // Complexity detection based on various factors
        let complexityIndicators = [
            "research", "analyze", "develop", "create", "design", "plan", "strategy",
            "implement", "coordinate", "manage", "review", "evaluate"
        ]
        
        let hasComplexityKeywords = complexityIndicators.contains { lowercaseTask.contains($0) }
        
        if words.count > 15 || hasComplexityKeywords {
            complexity = .complex
        } else if words.count > 8 {
            complexity = .moderate
        }
        
        // More sophisticated duration estimation
        let baseDuration: TimeInterval = switch priority {
        case 3: 45 * 60 // High priority tasks often need immediate attention
        case 2: 60 * 60 // Medium priority gets standard time
        case 1: 30 * 60 // Low priority might be quick
        default: 30 * 60
        }
        
        let estimatedDuration = baseDuration * complexity.estimatedDurationMultiplier
        
        return TaskAnalysis(
            suggestedPriority: priority,
            estimatedDuration: estimatedDuration,
            suggestedTags: tags,
            potentialSubtasks: generateSmartSubtasks(for: taskDescription, complexity: complexity),
            category: category,
            complexity: complexity
        )
    }
    
    func generateSmartSuggestions(_ context: String) async throws -> [SmartSuggestion] {
        // убрана искусственная задержка
        
        // Context-aware suggestions
        let suggestions = [
            SmartSuggestion(
                type: .productivity,
                title: "Time Block Similar Tasks",
                description: "Group similar tasks together to improve focus and reduce context switching",
                confidence: 0.85,
                actionable: true
            ),
            SmartSuggestion(
                type: .timeOptimization,
                title: "Optimize Morning Schedule",
                description: "Schedule high-priority tasks during your most productive hours (9-11 AM)",
                confidence: 0.78,
                actionable: true
            ),
            SmartSuggestion(
                type: .scheduleConflict,
                title: "Add Buffer Time",
                description: "Add 15-minute buffers between tasks to account for transitions and unexpected delays",
                confidence: 0.92,
                actionable: true
            ),
            SmartSuggestion(
                type: .taskBreakdown,
                title: "Break Down Complex Tasks",
                description: "Large tasks are easier to complete when broken into smaller, manageable steps",
                confidence: 0.88,
                actionable: true
            )
        ]
        
        AnalyticsService.shared.track(.aiSuggestionGenerated, properties: [
            "context_length": context.count,
            "suggestion_count": suggestions.count
        ])
        
        return suggestions
    }
    
    func optimizeSchedule(_ tasks: [TaskSummary]) async throws -> ScheduleOptimization {
        // убрана искусственная задержка
        
        let now = Date()
        let calendar = Calendar.current
        
        // Filter and sort tasks intelligently
        let pendingTasks = tasks
            .filter { !$0.isCompleted }
            .sorted { task1, task2 in
                // Primary sort: Priority
                if task1.priority != task2.priority {
                    return task1.priority > task2.priority
                }
                
                // Secondary sort: Due date proximity
                if let due1 = task1.dueDate, let due2 = task2.dueDate {
                    return due1 < due2
                }
                
                // Tertiary sort: Tasks with due dates first
                return task1.dueDate != nil && task2.dueDate == nil
            }
        
        var optimizedTasks: [OptimizedTask] = []
        var currentTime = getNextAvailableSlot(from: now)
        
        // Productive hours (based on research)
        let peakHours = 9...11  // Morning peak
        let goodHours = 14...16 // Afternoon good period
        
        for task in pendingTasks {
            let hour = calendar.component(.hour, from: currentTime)
            
            // Skip to next productive period if needed
            if hour < 9 {
                currentTime = calendar.nextDate(after: currentTime, matching: DateComponents(hour: 9), matchingPolicy: .nextTime) ?? currentTime
            } else if hour > 17 {
                let nextMorning = calendar.nextDate(after: currentTime, matching: DateComponents(hour: 9), matchingPolicy: .nextTime)
                currentTime = nextMorning ?? currentTime.addingTimeInterval(24 * 3600)
            }
            
            let confidence = calculateScheduleConfidence(
                task: task,
                scheduledTime: currentTime,
                isPeakHour: peakHours.contains(hour) || goodHours.contains(hour)
            )
            
            let optimizedTask = OptimizedTask(
                taskId: task.id,
                suggestedStartTime: currentTime,
                suggestedDuration: task.estimatedDuration,
                confidence: confidence
            )
            
            optimizedTasks.append(optimizedTask)
            
            // Add buffer time (15 minutes) between tasks
            currentTime = currentTime.addingTimeInterval(task.estimatedDuration + 900)
            
            // Don't schedule past 6 PM
            let endHour = calendar.component(.hour, from: currentTime)
            if endHour > 18 {
                let nextMorning = calendar.nextDate(after: currentTime, matching: DateComponents(hour: 9), matchingPolicy: .nextTime)
                currentTime = nextMorning ?? currentTime.addingTimeInterval(24 * 3600)
            }
        }
        
        let productivityScore = calculateOverallProductivityScore(optimizedTasks: optimizedTasks)
        
        let optimizationSuggestions = generateOptimizationSuggestions(optimizedTasks: optimizedTasks)
        
        return ScheduleOptimization(
            optimizedTasks: optimizedTasks,
            reasoning: "Schedule optimized based on task priorities, due dates, and your most productive hours. High-priority tasks are placed during peak performance times (9-11 AM and 2-4 PM).",
            productivityScore: productivityScore,
            suggestions: optimizationSuggestions
        )
    }
    
    func detectIntent(_ input: String) async throws -> UserIntent {
        let s = input.lowercased()
        // RU/EN create task
        if s.containsAny(["создай", "добавь", "создать", "добавить"]) && s.containsAny(["задач", "task"]) {
            return .createTask
        }
        if s.containsAny(["create", "add", "new task", "make a", "i need to"]) {
            return .createTask
        }
        // Modify / update
        if s.containsAny(["измени", "изменить", "обнови", "обновить", "переименуй"]) {
            return .modifyTask
        }
        if s.containsAny(["edit", "modify", "change", "update", "fix"]) { return .modifyTask }
        // Delete
        if s.containsAny(["удали", "удалить", "сотри", "убери"]) { return .deleteTask }
        if s.containsAny(["delete", "remove", "cancel"]) { return .deleteTask }
        // Schedule (includes meeting/event and planning verbs)
        if s.containsAny(["запланируй", "подбери", "найди", "распиши", "назначь"]) || s.contains("встреч") || s.contains("в календар") {
            return .scheduleTask
        }
        if s.containsAny(["schedule", "when should", "what time", "plan", "meeting", "calendar"]) {
            return .scheduleTask
        }
        // Suggestions
        if s.containsAny(["предложи", "подскажи", "порекомендуй"]) { return .requestSuggestion }
        if s.containsAny(["suggest", "recommend", "help me", "what should"]) { return .requestSuggestion }
        // Questions
        if s.containsAny(["?", "как", "что", "почему", "когда", "где", "сколько", "how", "what", "why", "when", "where"]) {
            return .askQuestion
        }
        return .unknown
    }

    func parseEvent(_ description: String) async throws -> EventDraft {
        let base = Date()
        let (start, end, allDay) = parseTime(from: description, base: base)
        let title = cleanEventTitle(from: description)
        return EventDraft(title: title, start: start, end: end, isAllDay: allDay)
    }
    
    // MARK: - Helper Methods
    private func generateSmartSubtasks(for taskDescription: String, complexity: TaskComplexity) -> [String] {
        let lowercaseTask = taskDescription.lowercased()
        
        // Context-aware subtask generation
        if lowercaseTask.contains("meeting") || lowercaseTask.contains("presentation") {
            return [
                "Prepare agenda and materials",
                "Send invitations and confirm attendance",
                "Conduct the meeting/presentation",
                "Follow up with action items"
            ]
        } else if lowercaseTask.contains("research") || lowercaseTask.contains("analyze") {
            return [
                "Define research scope and objectives",
                "Gather relevant sources and data",
                "Analyze findings and patterns",
                "Summarize results and conclusions"
            ]
        } else if lowercaseTask.contains("project") || lowercaseTask.contains("develop") {
            return [
                "Plan project structure and timeline",
                "Break down into specific tasks",
                "Execute implementation phase",
                "Test and review deliverables",
                "Finalize and document results"
            ]
        } else {
            // Generic subtasks based on complexity
            let baseSubtasks = switch complexity {
            case .simple:
                ["Complete the task", "Review and finalize"]
            case .moderate:
                ["Plan approach", "Execute main work", "Review results"]
            case .complex:
                ["Research and prepare", "Plan detailed approach", "Execute in phases", "Review and refine"]
            case .expert:
                ["Deep research and analysis", "Strategic planning", "Phased implementation", "Iterative refinement", "Final review and optimization"]
            }
            
            return baseSubtasks
        }
    }
    
    private func getNextAvailableSlot(from date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        // If it's outside working hours, move to next 9 AM
        if hour < 9 || hour > 17 {
            let nextMorning = calendar.nextDate(after: date, matching: DateComponents(hour: 9), matchingPolicy: .nextTime)
            return nextMorning ?? date.addingTimeInterval(3600)
        }
        
        // If it's lunch time (12-1 PM), skip to 1 PM
        if hour == 12 {
            let nextHour = calendar.nextDate(after: date, matching: DateComponents(hour: 13), matchingPolicy: .nextTime)
            return nextHour ?? date.addingTimeInterval(3600)
        }
        
        return date
    }

    // MARK: - Title sanitation for events
    private func cleanEventTitle(from raw: String) -> String {
        var s = raw
        let lowers = s.lowercased()
        // Strip scheduling verbs/boilerplate
        let verbs = [
            "создай","создать","добавь","добавить","запланируй","запланировать","назначь","назначить",
            "организуй","организовать","в календарь","добавь в календарь",
            "make","create","add","schedule","plan","put to calendar"
        ]
        for v in verbs { s = s.replacingOccurrences(of: v, with: " ", options: .caseInsensitive) }
        // Entity words
        let entities = ["встречу","встреча","митинг","meeting","событие","event"]
        for w in entities { s = s.replacingOccurrences(of: w, with: " ", options: .caseInsensitive) }
        // Day/time words
        let dayWords = ["сегодня","завтра","послезавтра","today","tomorrow","day after"]
        for w in dayWords { s = s.replacingOccurrences(of: w, with: " ", options: .caseInsensitive) }
        ["утра","вечера","дня","ночи","am","pm"].forEach { s = s.replacingOccurrences(of: $0, with: " ", options: .caseInsensitive) }
        // HH[:MM] and ranges
        s = s.replacingOccurrences(of: #"\bв\s*([01]?\d|2[0-3])([:\\.][0-5]\d)?\b"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"с\s*([01]?\d|2[0-3])([:\\.][0-5]\d)?\s*до\s*([01]?\d|2[0-3])([:\\.][0-5]\d)?"#, with: " ", options: .regularExpression)

        // Collapse spaces
        let cleaned = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty || cleaned.count < 3 { return entities.contains(where: { lowers.contains($0) }) ? "Встреча" : "Событие" }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }
    
    private func calculateScheduleConfidence(task: TaskSummary, scheduledTime: Date, isPeakHour: Bool) -> Double {
        var confidence = 0.7 // Base confidence
        
        // Higher confidence for high-priority tasks in peak hours
        if isPeakHour && task.priority >= 2 {
            confidence += 0.2
        }
        
        // Lower confidence if scheduled very close to due date
        if let dueDate = task.dueDate {
            let timeUntilDue = dueDate.timeIntervalSince(scheduledTime)
            let taskDurationWithBuffer = task.estimatedDuration * 1.5 // 50% buffer
            
            if timeUntilDue < taskDurationWithBuffer {
                confidence -= 0.4 // Significant penalty for tight deadlines
            } else if timeUntilDue < taskDurationWithBuffer * 2 {
                confidence -= 0.2 // Moderate penalty
            }
        }
        
        // Boost confidence for appropriately sized tasks
        let taskHours = task.estimatedDuration / 3600
        if taskHours >= 0.5 && taskHours <= 2.0 { // Sweet spot: 30min-2hours
            confidence += 0.1
        }
        
        return max(0.1, min(1.0, confidence))
    }
    
    private func calculateOverallProductivityScore(optimizedTasks: [OptimizedTask]) -> Double {
        guard !optimizedTasks.isEmpty else { return 0.0 }
        
        let averageConfidence = optimizedTasks.map(\.confidence).reduce(0, +) / Double(optimizedTasks.count)
        
        // Factor in schedule density (not too packed, not too sparse)
        let totalScheduledTime = optimizedTasks.reduce(0) { $0 + $1.suggestedDuration }
        let scheduleSpan = optimizedTasks.last?.suggestedStartTime.timeIntervalSince(optimizedTasks.first?.suggestedStartTime ?? Date()) ?? 0
        
        let density = scheduleSpan > 0 ? totalScheduledTime / scheduleSpan : 0
        let optimalDensity = 0.6 // 60% utilization is generally good
        let densityScore = 1.0 - abs(density - optimalDensity)
        
        return (averageConfidence * 0.7 + densityScore * 0.3)
    }
    
    private func generateOptimizationSuggestions(optimizedTasks: [OptimizedTask]) -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []
        
        // Check for low-confidence tasks
        let lowConfidenceTasks = optimizedTasks.filter { $0.confidence < 0.6 }
        if !lowConfidenceTasks.isEmpty {
            suggestions.append(SmartSuggestion(
                type: .scheduleConflict,
                title: "Review Tight Deadlines",
                description: "Some tasks are scheduled very close to their due dates. Consider adjusting deadlines or priorities.",
                confidence: 0.8,
                actionable: true
            ))
        }
        
        // Check for long consecutive work periods
        // Implementation would analyze gaps and suggest breaks
        
        return suggestions
    }
}

// MARK: - Legacy Support
typealias LLMProvider = LLMProviderProtocol

struct OnDeviceLLMStub: LLMProviderProtocol {
    func generateResponse(_ prompt: String) async throws -> String {
        return try await EnhancedLLMProvider.shared.generateResponse(prompt)
    }
    
    func analyzeTask(_ taskDescription: String) async throws -> TaskAnalysis {
        return try await EnhancedLLMProvider.shared.analyzeTask(taskDescription)
    }
    
    func generateSmartSuggestions(_ context: String) async throws -> [SmartSuggestion] {
        return try await EnhancedLLMProvider.shared.generateSmartSuggestions(context)
    }
    
    func optimizeSchedule(_ tasks: [TaskSummary]) async throws -> ScheduleOptimization {
        return try await EnhancedLLMProvider.shared.optimizeSchedule(tasks)
    }
    
    func detectIntent(_ input: String) async throws -> UserIntent {
        return try await EnhancedLLMProvider.shared.detectIntent(input)
    }
    
    func parseEvent(_ description: String) async throws -> EventDraft {
        return try await EnhancedLLMProvider.shared.parseEvent(description)
    }
    
    // Legacy method for backward compatibility
    func complete(prompt: String) async throws -> String {
        return try await generateResponse(prompt)
    }
}

// MARK: - Helpers
private extension String {
    func containsAny(_ subs: [String]) -> Bool { subs.contains { self.contains($0) } }
}

// Parse a simple time expression from text, return start/end and all-day flag
private func parseTime(from text: String, base: Date) -> (Date, Date, Bool) {
    let lower = text.lowercased()
    let cal = Calendar.current
    var day = cal.startOfDay(for: base)
    if lower.contains("завтра") || lower.contains("tomorrow") {
        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
    } else if lower.contains("послезавтра") || lower.contains("day after") {
        day = cal.date(byAdding: .day, value: 2, to: day) ?? day
    }

    // Try explicit range first
    if let (s, e) = parseTimeRange(from: lower, base: base) { return (s, e, false) }
    if let (s, e) = parseTimeRangeWords(from: lower, base: base) { return (s, e, false) }

    // Single time HH[:MM]
    guard let re = try? NSRegularExpression(pattern: "(^|\\s)([01]?\\d|2[0-3])[:\\.]?([0-5]\\d)?", options: []) else {
        let start = cal.date(byAdding: DateComponents(hour: 10, minute: 0), to: day) ?? base
        return (start, start.addingTimeInterval(3600), false)
    }
    var hour = 10, minute = 0
    if let m = re.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)), m.numberOfRanges >= 4,
       let hr = Range(m.range(at: 2), in: lower) {
        hour = Int(lower[hr]) ?? 10
        if let mnR = Range(m.range(at: 3), in: lower) { minute = Int(lower[mnR]) ?? 0 }
    }
    // Single word time like "в три" or "в час"
    if let wh = parseSingleWordHour(from: lower) { hour = wh }
    let pm = lower.contains("дня") || lower.contains("вечера") || lower.contains("pm")
    if pm && hour < 12 { hour += 12 }
    let start = cal.date(byAdding: DateComponents(hour: hour, minute: minute), to: day) ?? base
    let end = start.addingTimeInterval(3600)
    let allDay = lower.contains("весь день") || lower.contains("all day")
    return (start, end, allDay)
}

// Parse explicit range "с HH[:MM] до HH[:MM]" with optional RU PM markers
private func parseTimeRange(from text: String, base: Date) -> (Date, Date)? {
    let lower = text.lowercased()
    let cal = Calendar.current
    var day = cal.startOfDay(for: base)
    if lower.contains("завтра") || lower.contains("tomorrow") {
        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
    } else if lower.contains("послезавтра") || lower.contains("day after") {
        day = cal.date(byAdding: .day, value: 2, to: day) ?? day
    }
    guard let re = try? NSRegularExpression(pattern: "с\\s*([01]?\\d|2[0-3])(?::([0-5]\\d))?\\s*до\\s*([01]?\\d|2[0-3])(?::([0-5]\\d))?", options: [.caseInsensitive]) else { return nil }
    guard let m = re.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) else { return nil }
    func num(_ i: Int) -> Int? { if let r = Range(m.range(at: i), in: lower) { return Int(lower[r]) } else { return nil } }
    var sh = num(1) ?? 9
    let sm = num(2) ?? 0
    var eh = num(3) ?? (sh + 1)
    let em = num(4) ?? 0
    let pm = lower.contains("дня") || lower.contains("вечера") || lower.contains("pm")
    if pm { if sh < 12 { sh += 12 }; if eh < 12 { eh += 12 } }
    let start = cal.date(byAdding: DateComponents(hour: sh, minute: sm), to: day) ?? base
    let end = cal.date(byAdding: DateComponents(hour: eh, minute: em), to: day) ?? start.addingTimeInterval(3600)
    return (start, end)
}

// Parse explicit range with Russian words: "с часа до трёх (дня|вечера|утра)"
private func parseTimeRangeWords(from text: String, base: Date) -> (Date, Date)? {
    let lower = text
    let cal = Calendar.current
    var day = cal.startOfDay(for: base)
    if lower.contains("завтра") || lower.contains("tomorrow") { day = cal.date(byAdding: .day, value: 1, to: day) ?? day }
    if lower.contains("послезавтра") || lower.contains("day after") { day = cal.date(byAdding: .day, value: 2, to: day) ?? day }
    guard let sRange = lower.range(of: "с "), let dRange = lower.range(of: " до ") else { return nil }
    let startWord = lower[sRange.upperBound..<dRange.lowerBound].trimmingCharacters(in: .whitespaces)
    var afterDo = lower[dRange.upperBound...]
    // trim meridiem words at tail
    let meridiemPM = afterDo.contains("вечера") || afterDo.contains("дня") || afterDo.contains("pm")
    // Take first word after "до"
    let endWord = afterDo.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
    guard let sh = ruHour(fromWord: startWord), let eh = ruHour(fromWord: endWord) else { return nil }
    var startH = sh, endH = eh
    if meridiemPM { if startH < 12 { startH += 12 }; if endH < 12 { endH += 12 } }
    let start = cal.date(byAdding: DateComponents(hour: startH, minute: 0), to: day) ?? base
    let end = cal.date(byAdding: DateComponents(hour: endH, minute: 0), to: day) ?? start.addingTimeInterval(3600)
    return (start, end)
}

// Parse single word hour like "в три", returns 0-23 or nil
private func parseSingleWordHour(from text: String) -> Int? {
    guard let r = text.range(of: "в ") else { return nil }
    let tail = text[r.upperBound...]
    let word = tail.split(whereSeparator: { !$0.isLetter }).first.map(String.init) ?? ""
    return ruHour(fromWord: word)
}

// Map Russian word forms to hour (1-12)
private func ruHour(fromWord raw: String) -> Int? {
    let w = raw.replacingOccurrences(of: "ё", with: "е")
    let map: [Int: [String]] = [
        1: ["час", "часа", "один", "одного"],
        2: ["два", "двух"],
        3: ["три", "трех", "трёх"],
        4: ["четыре", "четырех", "четырех"],
        5: ["пять", "пяти"],
        6: ["шесть", "шести"],
        7: ["семь", "семи"],
        8: ["восемь", "восьми"],
        9: ["девять", "девяти"],
        10: ["десять", "десяти"],
        11: ["одиннадцать", "одиннадцати"],
        12: ["двенадцать", "двенадцати"]
    ]
    for (h, arr) in map { if arr.contains(where: { w.contains($0) }) { return h } }
    return nil
}

// Analytics (used in suggestions)
extension AnalyticsEvent {
    static let aiSuggestionGenerated = AnalyticsEvent(rawValue: "ai_suggestion_generated")!
}
