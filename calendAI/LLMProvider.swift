import Foundation

// MARK: - Enhanced LLM Provider Protocol
protocol LLMProviderProtocol {
    func generateResponse(_ prompt: String) async throws -> String
    func analyzeTask(_ taskDescription: String) async throws -> TaskAnalysis
    func generateSmartSuggestions(_ context: String) async throws -> [SmartSuggestion]
    func optimizeSchedule(_ tasks: [TaskSummary]) async throws -> ScheduleOptimization
    func detectIntent(_ input: String) async throws -> UserIntent
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
        You are CalendAI, an intelligent personal assistant that helps users manage their tasks and schedule efficiently.
        
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
        // Smart response generation based on context
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 second delay
        
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
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 second delay
        
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
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 second delay
        
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
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay for complex optimization
        
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
        let lowercaseInput = input.lowercased()
        
        // Enhanced intent detection with better patterns
        if lowercaseInput.matches(patterns: ["create", "add", "new task", "make a", "i need to"]) {
            return .createTask
        } else if lowercaseInput.matches(patterns: ["edit", "modify", "change", "update", "fix"]) {
            return .modifyTask
        } else if lowercaseInput.matches(patterns: ["delete", "remove", "cancel", "get rid of"]) {
            return .deleteTask
        } else if lowercaseInput.matches(patterns: ["schedule", "when should", "what time", "plan"]) {
            return .scheduleTask
        } else if lowercaseInput.matches(patterns: ["suggest", "recommend", "help me", "what should"]) {
            return .requestSuggestion
        } else if lowercaseInput.matches(patterns: ["?", "how", "what", "why", "when", "where"]) {
            return .askQuestion
        } else {
            return .unknown
        }
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
    
    // Legacy method for backward compatibility
    func complete(prompt: String) async throws -> String {
        return try await generateResponse(prompt)
    }
}

// MARK: - String Extension for Pattern Matching
extension String {
    func matches(patterns: [String]) -> Bool {
        return patterns.contains { self.contains($0) }
    }
}

// MARK: - Analytics Extensions
extension AnalyticsEvent {
    static let aiSuggestionGenerated = AnalyticsEvent(rawValue: "ai_suggestion_generated")!
}

// MARK: - Legacy AIIntent Support
struct AIIntent: Codable {
    let action: String
    let payload: [String: String]?
    let meta: Meta
    
    struct Meta: Codable {
        let confidence: Double
        let requiresConfirmation: Bool
    }
}
