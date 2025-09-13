import Foundation
import CoreData
import EventKit
import UserNotifications
import SwiftUI

// MARK: - Conflict Detection Service
@MainActor
final class ConflictDetectionService: ObservableObject {
    static let shared = ConflictDetectionService()
    
    @Published var detectedConflicts: [ScheduleConflict] = []
    @Published var isAnalyzing = false
    
    private let eventStore = EKEventStore()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // Conflict types
    enum ConflictType: String, CaseIterable {
        case timeOverlap = "time_overlap"
        case locationConflict = "location_conflict"
        case resourceConflict = "resource_conflict"
        case energyConflict = "energy_conflict"
        case priorityConflict = "priority_conflict"
        
        var displayName: String {
            switch self {
            case .timeOverlap: return "Time Overlap"
            case .locationConflict: return "Location Conflict"
            case .resourceConflict: return "Resource Conflict"
            case .energyConflict: return "Energy Conflict"
            case .priorityConflict: return "Priority Conflict"
            }
        }
        
        var icon: String {
            switch self {
            case .timeOverlap: return "clock.badge.exclamationmark"
            case .locationConflict: return "location.badge.exclamationmark"
            case .resourceConflict: return "person.2.badge.minus"
            case .energyConflict: return "battery.25"
            case .priorityConflict: return "exclamationmark.triangle"
            }
        }
        
        var color: Color {
            switch self {
            case .timeOverlap: return DesignSystem.Colors.overdue
            case .locationConflict: return DesignSystem.Colors.priorityMedium
            case .resourceConflict: return DesignSystem.Colors.primaryBlue
            case .energyConflict: return DesignSystem.Colors.priorityLow
            case .priorityConflict: return DesignSystem.Colors.priorityHigh
            }
        }
        
        var severity: ConflictSeverity {
            switch self {
            case .timeOverlap: return .critical
            case .locationConflict: return .high
            case .resourceConflict: return .medium
            case .energyConflict: return .low
            case .priorityConflict: return .high
            }
        }
    }
    
    enum ConflictSeverity: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
        
        var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
        
        var color: Color {
            switch self {
            case .low: return DesignSystem.Colors.priorityNone
            case .medium: return DesignSystem.Colors.priorityLow
            case .high: return DesignSystem.Colors.priorityMedium
            case .critical: return DesignSystem.Colors.priorityHigh
            }
        }
    }
    
    // Conflict resolution suggestions
    enum ResolutionSuggestion: String, CaseIterable {
        case reschedule = "reschedule"
        case adjustDuration = "adjust_duration"
        case changePriority = "change_priority"
        case delegate = "delegate"
        case cancel = "cancel"
        case remote = "make_remote"
        
        var displayName: String {
            switch self {
            case .reschedule: return "Reschedule"
            case .adjustDuration: return "Adjust Duration"
            case .changePriority: return "Change Priority"
            case .delegate: return "Delegate"
            case .cancel: return "Cancel"
            case .remote: return "Make Remote"
            }
        }
        
        var icon: String {
            switch self {
            case .reschedule: return "calendar.badge.plus"
            case .adjustDuration: return "timer.square"
            case .changePriority: return "slider.horizontal.3"
            case .delegate: return "person.badge.plus"
            case .cancel: return "xmark.circle"
            case .remote: return "video"
            }
        }
    }
    
    private init() {
        setupConflictDetection()
    }
    
    // MARK: - Setup
    private func setupConflictDetection() {
        // Set up real-time conflict detection
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                await self.analyzeScheduleConflicts()
            }
        }
    }
    
    // MARK: - Main Conflict Detection
    func analyzeScheduleConflicts(context: NSManagedObjectContext? = nil) async {
        isAnalyzing = true
        
        let managedContext = context ?? PersistenceController.shared.container.viewContext
        
        await withTaskGroup(of: Void.self) { group in
            // Analyze different types of conflicts in parallel
            group.addTask {
                await self.detectTimeOverlapConflicts(context: managedContext)
            }
            
            group.addTask {
                await self.detectLocationConflicts(context: managedContext)
            }
            
            group.addTask {
                await self.detectResourceConflicts(context: managedContext)
            }
            
            group.addTask {
                await self.detectEnergyConflicts(context: managedContext)
            }
            
            group.addTask {
                await self.detectPriorityConflicts(context: managedContext)
            }
        }
        
        // Sort conflicts by severity and time
        detectedConflicts.sort { conflict1, conflict2 in
            if conflict1.severity == conflict2.severity {
                return conflict1.detectedAt > conflict2.detectedAt
            }
            return conflict1.severity.rawValue > conflict2.severity.rawValue
        }
        
        // Notify user of critical conflicts
        await notifyCriticalConflicts()
        
        isAnalyzing = false
        
        AnalyticsService.shared.track(.conflictsDetected, properties: [
            "total_conflicts": detectedConflicts.count,
            "critical_conflicts": detectedConflicts.filter { $0.severity == .critical }.count
        ])
    }
    
    // MARK: - Time Overlap Detection
    private func detectTimeOverlapConflicts(context: NSManagedObjectContext) async {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dueDate != nil AND isCompleted == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        
        do {
            let tasks = try context.fetch(request)
            
            // Check tasks against each other
            for i in 0..<tasks.count {
                for j in (i+1)..<tasks.count {
                    if let conflict = checkTimeOverlap(task1: tasks[i], task2: tasks[j]) {
                        if !detectedConflicts.contains(where: { $0.id == conflict.id }) {
                            detectedConflicts.append(conflict)
                        }
                    }
                }
            }
            
            // Check tasks against calendar events
            await checkTasksAgainstCalendarEvents(tasks: tasks, context: context)
            
        } catch {
            print("❌ Error fetching tasks for conflict detection: \(error)")
        }
    }
    
    private func checkTimeOverlap(task1: TaskEntity, task2: TaskEntity) -> ScheduleConflict? {
        guard let dueDate1 = task1.dueDate,
              let dueDate2 = task2.dueDate else { return nil }
        
        // Estimate task duration based on priority and complexity
        let duration1 = estimateTaskDuration(task1)
        let duration2 = estimateTaskDuration(task2)
        
        let end1 = dueDate1.addingTimeInterval(duration1)
        let end2 = dueDate2.addingTimeInterval(duration2)
        
        // Check for overlap
        let hasOverlap = (dueDate1 < end2) && (dueDate2 < end1)
        
        if hasOverlap {
            let overlapDuration = min(end1, end2).timeIntervalSince(max(dueDate1, dueDate2))
            
            return ScheduleConflict(
                type: .timeOverlap,
                severity: overlapDuration > 1800 ? .critical : .high, // > 30 minutes
                title: "Time Overlap Detected",
                description: "Tasks '\(task1.title ?? "Task")' and '\(task2.title ?? "Task")' have overlapping time slots",
                affectedItems: [task1.id, task2.id].compactMap { $0 },
                suggestedResolutions: [.reschedule, .adjustDuration],
                detectedAt: Date()
            )
        }
        
        return nil
    }
    
    private func checkTasksAgainstCalendarEvents(tasks: [TaskEntity], context: NSManagedObjectContext) async {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        
        for task in tasks {
            guard let taskDate = task.dueDate else { continue }
            
            let startDate = Calendar.current.startOfDay(for: taskDate)
            let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
            
            let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
            let events = eventStore.events(matching: predicate)
            
            for event in events {
                if let conflict = checkTaskEventOverlap(task: task, event: event) {
                    if !detectedConflicts.contains(where: { $0.id == conflict.id }) {
                        detectedConflicts.append(conflict)
                    }
                }
            }
        }
    }
    
    private func checkTaskEventOverlap(task: TaskEntity, event: EKEvent) -> ScheduleConflict? {
        guard let taskDate = task.dueDate else { return nil }
        
        let taskDuration = estimateTaskDuration(task)
        let taskEnd = taskDate.addingTimeInterval(taskDuration)
        
        // Check for overlap
        let hasOverlap = (taskDate < event.endDate) && (event.startDate < taskEnd)
        
        if hasOverlap {
            return ScheduleConflict(
                type: .timeOverlap,
                severity: .high,
                title: "Calendar Event Conflict",
                description: "Task '\(task.title ?? "Task")' overlaps with calendar event '\(event.title ?? "Untitled Event")'",
                affectedItems: [task.id].compactMap { $0 },
                suggestedResolutions: [.reschedule, .adjustDuration],
                detectedAt: Date()
            )
        }
        
        return nil
    }
    
    // MARK: - Location Conflict Detection
    private func detectLocationConflicts(context: NSManagedObjectContext) async {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dueDate != nil AND isCompleted == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        
        do {
            let tasks = try context.fetch(request)
            
            // Simulate location conflicts based on task tags or notes containing location keywords
            let locationKeywords = ["office", "home", "meeting", "client", "remote", "onsite"]
            
            for i in 0..<tasks.count {
                for j in (i+1)..<tasks.count {
                    let task1 = tasks[i]
                    let task2 = tasks[j]
                    
                    guard let date1 = task1.dueDate,
                          let date2 = task2.dueDate,
                          abs(date1.timeIntervalSince(date2)) < 7200 else { continue } // Within 2 hours
                    
                    let task1Location = extractLocation(from: task1)
                    let task2Location = extractLocation(from: task2)
                    
                    if task1Location != task2Location && task1Location != "unknown" && task2Location != "unknown" {
                        let conflict = ScheduleConflict(
                            type: .locationConflict,
                            severity: .high,
                            title: "Location Conflict Detected",
                            description: "Tasks '\(task1.title ?? "Task")' and '\(task2.title ?? "Task")' require different locations within 2 hours",
                            affectedItems: [task1.id, task2.id].compactMap { $0 },
                            suggestedResolutions: [.reschedule, .remote, .delegate],
                            detectedAt: Date()
                        )
                        
                        if !detectedConflicts.contains(where: { $0.id == conflict.id }) {
                            detectedConflicts.append(conflict)
                        }
                    }
                }
            }
        } catch {
            print("❌ Error detecting location conflicts: \(error)")
        }
    }
    
    private func extractLocation(from task: TaskEntity) -> String {
        let text = "\(task.title ?? "") \(task.notes ?? "")".lowercased()
        
        if text.contains("office") || text.contains("работа") { return "office" }
        if text.contains("home") || text.contains("дом") { return "home" }
        if text.contains("client") || text.contains("клиент") { return "client" }
        if text.contains("remote") || text.contains("удаленно") { return "remote" }
        if text.contains("meeting") || text.contains("встреча") { return "meeting" }
        
        return "unknown"
    }
    
    // MARK: - Resource Conflict Detection
    private func detectResourceConflicts(context: NSManagedObjectContext) async {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dueDate != nil AND isCompleted == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        
        do {
            let tasks = try context.fetch(request)
            
            // Group tasks by resource requirements (extracted from notes/tags)
            var resourceGroups: [String: [TaskEntity]] = [:]
            
            for task in tasks {
                let resources = extractResources(from: task)
                for resource in resources {
                    resourceGroups[resource, default: []].append(task)
                }
            }
            
            // Check for conflicts in each resource group
            for (resource, resourceTasks) in resourceGroups {
                guard resourceTasks.count > 1 else { continue }
                
                for i in 0..<resourceTasks.count {
                    for j in (i+1)..<resourceTasks.count {
                        let task1 = resourceTasks[i]
                        let task2 = resourceTasks[j]
                        
                        guard let date1 = task1.dueDate,
                              let date2 = task2.dueDate else { continue }
                        
                        let duration1 = estimateTaskDuration(task1)
                        let duration2 = estimateTaskDuration(task2)
                        
                        let end1 = date1.addingTimeInterval(duration1)
                        let end2 = date2.addingTimeInterval(duration2)
                        
                        // Check for overlap
                        if (date1 < end2) && (date2 < end1) {
                            let conflict = ScheduleConflict(
                                type: .resourceConflict,
                                severity: .medium,
                                title: "Resource Conflict Detected",
                                description: "Resource '\(resource)' is needed for both '\(task1.title ?? "Task")' and '\(task2.title ?? "Task")' at overlapping times",
                                affectedItems: [task1.id, task2.id].compactMap { $0 },
                                suggestedResolutions: [.reschedule, .delegate, .adjustDuration],
                                detectedAt: Date()
                            )
                            
                            if !detectedConflicts.contains(where: { $0.id == conflict.id }) {
                                detectedConflicts.append(conflict)
                            }
                        }
                    }
                }
            }
        } catch {
            print("❌ Error detecting resource conflicts: \(error)")
        }
    }
    
    private func extractResources(from task: TaskEntity) -> [String] {
        let text = "\(task.title ?? "") \(task.notes ?? "")".lowercased()
        var resources: [String] = []
        
        // Extract common resource keywords
        if text.contains("team") || text.contains("команда") { resources.append("team") }
        if text.contains("manager") || text.contains("менеджер") { resources.append("manager") }
        if text.contains("computer") || text.contains("компьютер") { resources.append("computer") }
        if text.contains("room") || text.contains("комната") { resources.append("room") }
        if text.contains("phone") || text.contains("телефон") { resources.append("phone") }
        if text.contains("document") || text.contains("документ") { resources.append("documents") }
        
        return resources.isEmpty ? ["generic"] : resources
    }
    
    // MARK: - Energy Conflict Detection
    private func detectEnergyConflicts(context: NSManagedObjectContext) async {
        // Implementation for energy-based conflicts (too many high-energy tasks in a row)
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dueDate != nil AND isCompleted == NO AND priority >= 2")
        request.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        
        do {
            let highPriorityTasks = try context.fetch(request)
            
            // Check for too many high-priority tasks in a short timeframe
            var consecutiveHighPriority = 0
            var lastTaskTime: Date?
            
            for task in highPriorityTasks {
                guard let taskDate = task.dueDate else { continue }
                
                if let lastTime = lastTaskTime,
                   taskDate.timeIntervalSince(lastTime) < 3600 { // Less than 1 hour apart
                    consecutiveHighPriority += 1
                    
                    if consecutiveHighPriority >= 3 {
                        let conflict = ScheduleConflict(
                            type: .energyConflict,
                            severity: .medium,
                            title: "Energy Overload Detected",
                            description: "Too many high-priority tasks scheduled consecutively",
                            affectedItems: [task.id].compactMap { $0 },
                            suggestedResolutions: [.reschedule, .changePriority],
                            detectedAt: Date()
                        )
                        
                        if !detectedConflicts.contains(where: { $0.id == conflict.id }) {
                            detectedConflicts.append(conflict)
                        }
                    }
                } else {
                    consecutiveHighPriority = 1
                }
                
                lastTaskTime = taskDate
            }
        } catch {
            print("❌ Error detecting energy conflicts: \(error)")
        }
    }
    
    // MARK: - Priority Conflict Detection
    private func detectPriorityConflicts(context: NSManagedObjectContext) async {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dueDate != nil AND isCompleted == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        
        do {
            let tasks = try context.fetch(request)
            let now = Date()
            
            // Check for high-priority tasks scheduled after lower-priority ones with earlier due dates
            for i in 0..<tasks.count {
                for j in (i+1)..<tasks.count {
                    let earlierTask = tasks[i]
                    let laterTask = tasks[j]
                    
                    guard let earlierDate = earlierTask.dueDate,
                          let laterDate = laterTask.dueDate,
                          laterDate > earlierDate else { continue }
                    
                    // Priority conflict: high priority task scheduled after lower priority
                    if laterTask.priority > earlierTask.priority && 
                       laterDate.timeIntervalSince(now) < 86400 { // Within 24 hours
                        
                        let conflict = ScheduleConflict(
                            type: .priorityConflict,
                            severity: .high,
                            title: "Priority Order Conflict",
                            description: "High-priority task '\(laterTask.title ?? "Task")' is scheduled after lower-priority task '\(earlierTask.title ?? "Task")'",
                            affectedItems: [earlierTask.id, laterTask.id].compactMap { $0 },
                            suggestedResolutions: [.reschedule, .changePriority],
                            detectedAt: Date()
                        )
                        
                        if !detectedConflicts.contains(where: { $0.id == conflict.id }) {
                            detectedConflicts.append(conflict)
                        }
                    }
                    
                    // Check for overdue high-priority tasks
                    if laterTask.priority >= 2 && laterDate < now {
                        let conflict = ScheduleConflict(
                            type: .priorityConflict,
                            severity: .critical,
                            title: "Overdue High-Priority Task",
                            description: "High-priority task '\(laterTask.title ?? "Task")' is overdue",
                            affectedItems: [laterTask.id].compactMap { $0 },
                            suggestedResolutions: [.reschedule, .changePriority],
                            detectedAt: Date()
                        )
                        
                        if !detectedConflicts.contains(where: { $0.id == conflict.id }) {
                            detectedConflicts.append(conflict)
                        }
                    }
                }
            }
        } catch {
            print("❌ Error detecting priority conflicts: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func estimateTaskDuration(_ task: TaskEntity) -> TimeInterval {
        // AI-based duration estimation
        let baseDuration: TimeInterval = switch Int(task.priority) {
        case 3: 3600 // High priority: 1 hour
        case 2: 1800 // Medium priority: 30 minutes
        case 1: 900  // Low priority: 15 minutes
        default: 1200 // No priority: 20 minutes
        }
        
        // Adjust based on notes length (complexity indicator)
        let notesLength = task.notes?.count ?? 0
        let complexityMultiplier = 1.0 + (Double(notesLength) / 500.0) // Longer notes = more complex
        
        return baseDuration * complexityMultiplier
    }
    
    // MARK: - Notifications
    private func notifyCriticalConflicts() async {
        let criticalConflicts = detectedConflicts.filter { $0.severity == .critical }
        
        for conflict in criticalConflicts {
            let content = UNMutableNotificationContent()
            content.title = "⚠️ Critical Schedule Conflict"
            content.body = conflict.description
            content.sound = .default
            content.categoryIdentifier = "CONFLICT_ALERT"
            
            content.userInfo = [
                "conflict_id": conflict.id.uuidString,
                "conflict_type": conflict.type.rawValue
            ]
            
            let request = UNNotificationRequest(
                identifier: "conflict_\(conflict.id.uuidString)",
                content: content,
                trigger: nil // Immediate notification
            )
            
            try? await notificationCenter.add(request)
        }
    }
    
    // MARK: - Conflict Resolution
    func resolveConflict(_ conflict: ScheduleConflict, with resolution: ResolutionSuggestion, context: NSManagedObjectContext) async {
        switch resolution {
        case .reschedule:
            await rescheduleConflictedTasks(conflict, context: context)
        case .adjustDuration:
            await adjustTaskDurations(conflict, context: context)
        case .changePriority:
            await adjustTaskPriorities(conflict, context: context)
        case .delegate:
            // Implementation for delegation
            break
        case .cancel:
            await cancelConflictedTask(conflict, context: context)
        case .remote:
            // Mark as remote/virtual
            break
        }
        
        // Remove resolved conflict
        detectedConflicts.removeAll { $0.id == conflict.id }
        
        AnalyticsService.shared.track(.conflictResolved, properties: [
            "conflict_type": conflict.type.rawValue,
            "resolution": resolution.rawValue
        ])
    }
    
    private func rescheduleConflictedTasks(_ conflict: ScheduleConflict, context: NSManagedObjectContext) async {
        for taskId in conflict.affectedItems {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)
            
            do {
                if let task = try context.fetch(request).first,
                   let currentDueDate = task.dueDate {
                    
                    // Find next available time slot (add 2 hours)
                    let newDueDate = currentDueDate.addingTimeInterval(7200)
                    task.dueDate = newDueDate
                    task.updatedAt = Date()
                    
                    // Reschedule notification
                    await NotificationService.scheduleTaskReminder(task)
                    
                    try context.save()
                    
                    print("✅ Rescheduled task '\(task.title ?? "Task")' to \(newDueDate)")
                }
            } catch {
                print("❌ Error rescheduling task: \(error)")
            }
        }
    }
    
    private func adjustTaskDurations(_ conflict: ScheduleConflict, context: NSManagedObjectContext) async {
        // Reduce estimated duration by creating subtasks or simplifying scope
        for taskId in conflict.affectedItems {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)
            
            do {
                if let task = try context.fetch(request).first {
                    // Add note about duration adjustment
                    let currentNotes = task.notes ?? ""
                    task.notes = "\(currentNotes)\n[Auto-adjusted: Duration optimized to resolve conflict]"
                    task.updatedAt = Date()
                    
                    try context.save()
                    
                    print("✅ Adjusted duration for task '\(task.title ?? "Task")' to resolve conflict")
                }
            } catch {
                print("❌ Error adjusting task duration: \(error)")
            }
        }
    }
    
    private func adjustTaskPriorities(_ conflict: ScheduleConflict, context: NSManagedObjectContext) async {
        for taskId in conflict.affectedItems {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)
            
            do {
                if let task = try context.fetch(request).first {
                    // Lower priority to resolve conflict (but not below 0)
                    if task.priority > 0 {
                        task.priority = max(0, task.priority - 1)
                        task.updatedAt = Date()
                        
                        // Update notification based on new priority
                        await NotificationService.scheduleTaskReminder(task)
                        
                        try context.save()
                        
                        print("✅ Adjusted priority for task '\(task.title ?? "Task")' from \(task.priority + 1) to \(task.priority)")
                    }
                }
            } catch {
                print("❌ Error adjusting task priority: \(error)")
            }
        }
    }
    
    private func cancelConflictedTask(_ conflict: ScheduleConflict, context: NSManagedObjectContext) async {
        // Cancel the lowest priority task in the conflict
        var lowestPriorityTask: TaskEntity?
        var lowestPriority: Int16 = Int16.max
        
        for taskId in conflict.affectedItems {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)
            
            do {
                if let task = try context.fetch(request).first {
                    if task.priority < lowestPriority {
                        lowestPriority = task.priority
                        lowestPriorityTask = task
                    }
                }
            } catch {
                print("❌ Error fetching task for cancellation: \(error)")
            }
        }
        
        // Mark the lowest priority task as completed (soft cancellation)
        if let taskToCancel = lowestPriorityTask {
            do {
                taskToCancel.isCompleted = true
                taskToCancel.updatedAt = Date()
                
                // Add cancellation note
                let currentNotes = taskToCancel.notes ?? ""
                taskToCancel.notes = "\(currentNotes)\n[Auto-cancelled: Resolved schedule conflict on \(Date().formatted())]"
                
                // Cancel notification
                if let taskId = taskToCancel.id {
                    NotificationService.cancelReminder(for: taskId)
                }
                
                try context.save()
                
                print("✅ Cancelled task '\(taskToCancel.title ?? "Task")' to resolve conflict")
            } catch {
                print("❌ Error cancelling task: \(error)")
            }
        }
    }
}

// MARK: - Schedule Conflict Model
struct ScheduleConflict: Identifiable, Hashable {
    let id = UUID()
    let type: ConflictDetectionService.ConflictType
    let severity: ConflictDetectionService.ConflictSeverity
    let title: String
    let description: String
    let affectedItems: [UUID] // Task or event IDs
    let suggestedResolutions: [ConflictDetectionService.ResolutionSuggestion]
    let detectedAt: Date
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ScheduleConflict, rhs: ScheduleConflict) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Analytics Extensions
extension AnalyticsEvent {
    static let conflictsDetected = AnalyticsEvent(rawValue: "conflicts_detected")!
    static let conflictResolved = AnalyticsEvent(rawValue: "conflict_resolved")!
}