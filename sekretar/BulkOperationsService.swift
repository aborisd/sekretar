import Foundation
import CoreData
import SwiftUI

// MARK: - Bulk Operations Service
/// Массовые операции с задачами (BRD строка 78)
@MainActor
final class BulkOperationsService: ObservableObject {
    static let shared = BulkOperationsService()

    @Published var selectedTasks: Set<UUID> = []
    @Published var isPerformingOperation = false
    @Published var lastOperationResult: OperationResult?

    private init() {}

    // MARK: - Selection Management

    func toggleSelection(_ taskId: UUID) {
        if selectedTasks.contains(taskId) {
            selectedTasks.remove(taskId)
        } else {
            selectedTasks.insert(taskId)
        }
    }

    func selectAll(tasks: [TaskEntity]) {
        selectedTasks = Set(tasks.compactMap { $0.id })
    }

    func deselectAll() {
        selectedTasks.removeAll()
    }

    func isSelected(_ taskId: UUID) -> Bool {
        selectedTasks.contains(taskId)
    }

    // MARK: - Bulk Operations

    /// Массовое завершение задач
    func completeSelected(context: NSManagedObjectContext) async throws {
        guard !selectedTasks.isEmpty else { return }

        isPerformingOperation = true
        defer { isPerformingOperation = false }

        let taskIds = Array(selectedTasks)
        var completedCount = 0

        for taskId in taskIds {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)

            do {
                if let task = try context.fetch(request).first {
                    task.isCompleted = true
                    task.updatedAt = Date()
                    completedCount += 1

                    // Cancel notifications
                    NotificationService.cancelReminder(for: taskId)
                }
            } catch {
                print("❌ Error completing task \(taskId): \(error)")
            }
        }

        try context.save()
        deselectAll()

        lastOperationResult = OperationResult(
            operation: .complete,
            affectedCount: completedCount,
            success: true
        )

        AnalyticsService.shared.track(.bulkOperation, properties: [
            "operation": "complete",
            "count": completedCount
        ])
    }

    /// Массовое удаление задач
    func deleteSelected(context: NSManagedObjectContext) async throws {
        guard !selectedTasks.isEmpty else { return }

        isPerformingOperation = true
        defer { isPerformingOperation = false }

        let taskIds = Array(selectedTasks)
        var deletedCount = 0

        for taskId in taskIds {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)

            do {
                if let task = try context.fetch(request).first {
                    context.delete(task)
                    deletedCount += 1

                    // Cancel notifications
                    NotificationService.cancelReminder(for: taskId)
                }
            } catch {
                print("❌ Error deleting task \(taskId): \(error)")
            }
        }

        try context.save()
        deselectAll()

        lastOperationResult = OperationResult(
            operation: .delete,
            affectedCount: deletedCount,
            success: true
        )

        AnalyticsService.shared.track(.bulkOperation, properties: [
            "operation": "delete",
            "count": deletedCount
        ])
    }

    /// Массовое изменение приоритета
    func changePrioritySelected(
        to priority: Int16,
        context: NSManagedObjectContext
    ) async throws {
        guard !selectedTasks.isEmpty else { return }

        isPerformingOperation = true
        defer { isPerformingOperation = false }

        let taskIds = Array(selectedTasks)
        var updatedCount = 0

        for taskId in taskIds {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)

            do {
                if let task = try context.fetch(request).first {
                    task.priority = priority
                    task.updatedAt = Date()
                    updatedCount += 1

                    // Update notification based on new priority
                    await NotificationService.scheduleTaskReminder(task)
                }
            } catch {
                print("❌ Error updating task priority \(taskId): \(error)")
            }
        }

        try context.save()
        deselectAll()

        lastOperationResult = OperationResult(
            operation: .changePriority,
            affectedCount: updatedCount,
            success: true
        )

        AnalyticsService.shared.track(.bulkOperation, properties: [
            "operation": "change_priority",
            "priority": Int(priority),
            "count": updatedCount
        ])
    }

    /// Массовое перемещение в проект
    func moveToProjectSelected(
        projectId: UUID,
        context: NSManagedObjectContext
    ) async throws {
        guard !selectedTasks.isEmpty else { return }

        isPerformingOperation = true
        defer { isPerformingOperation = false }

        // Verify project exists
        let projectRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        projectRequest.predicate = NSPredicate(format: "id == %@", projectId as CVarArg)
        guard let project = try context.fetch(projectRequest).first else {
            throw BulkOperationError.projectNotFound
        }

        let taskIds = Array(selectedTasks)
        var movedCount = 0

        for taskId in taskIds {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)

            do {
                if let task = try context.fetch(request).first {
                    task.projectID = projectId
                    task.project = project
                    task.updatedAt = Date()
                    movedCount += 1
                }
            } catch {
                print("❌ Error moving task \(taskId): \(error)")
            }
        }

        try context.save()
        deselectAll()

        lastOperationResult = OperationResult(
            operation: .moveToProject,
            affectedCount: movedCount,
            success: true
        )

        AnalyticsService.shared.track(.bulkOperation, properties: [
            "operation": "move_to_project",
            "count": movedCount
        ])
    }

    /// Массовое добавление тегов
    func addTagsSelected(
        tags: [String],
        context: NSManagedObjectContext
    ) async throws {
        guard !selectedTasks.isEmpty else { return }

        isPerformingOperation = true
        defer { isPerformingOperation = false }

        let taskIds = Array(selectedTasks)
        var updatedCount = 0

        for taskId in taskIds {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)

            do {
                if let task = try context.fetch(request).first {
                    let existingTags = (task.tags ?? "")
                        .split(separator: ",")
                        .map(String.init)
                        .map { $0.trimmingCharacters(in: .whitespaces) }

                    let allTags = Set(existingTags + tags)
                    task.tags = allTags.joined(separator: ",")
                    task.updatedAt = Date()
                    updatedCount += 1
                }
            } catch {
                print("❌ Error adding tags to task \(taskId): \(error)")
            }
        }

        try context.save()
        deselectAll()

        lastOperationResult = OperationResult(
            operation: .addTags,
            affectedCount: updatedCount,
            success: true
        )

        AnalyticsService.shared.track(.bulkOperation, properties: [
            "operation": "add_tags",
            "tags": tags.joined(separator: ","),
            "count": updatedCount
        ])
    }

    /// Массовое установление дедлайна
    func setDueDateSelected(
        date: Date,
        context: NSManagedObjectContext
    ) async throws {
        guard !selectedTasks.isEmpty else { return }

        isPerformingOperation = true
        defer { isPerformingOperation = false }

        let taskIds = Array(selectedTasks)
        var updatedCount = 0

        for taskId in taskIds {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)

            do {
                if let task = try context.fetch(request).first {
                    task.dueDate = date
                    task.updatedAt = Date()
                    updatedCount += 1

                    // Schedule notification
                    await NotificationService.scheduleTaskReminder(task)
                }
            } catch {
                print("❌ Error setting due date for task \(taskId): \(error)")
            }
        }

        try context.save()
        deselectAll()

        lastOperationResult = OperationResult(
            operation: .setDueDate,
            affectedCount: updatedCount,
            success: true
        )

        AnalyticsService.shared.track(.bulkOperation, properties: [
            "operation": "set_due_date",
            "count": updatedCount
        ])
    }

    /// Массовое автопланирование
    func autoScheduleSelected(context: NSManagedObjectContext) async throws {
        guard !selectedTasks.isEmpty else { return }

        isPerformingOperation = true
        defer { isPerformingOperation = false }

        let taskIds = Array(selectedTasks)
        var scheduledCount = 0
        var tasks: [TaskEntity] = []

        // Fetch all selected tasks
        for taskId in taskIds {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)

            do {
                if let task = try context.fetch(request).first {
                    tasks.append(task)
                }
            } catch {
                print("❌ Error fetching task \(taskId): \(error)")
            }
        }

        // Use AutoSchedulerService to schedule all tasks
        do {
            try await AutoSchedulerService.shared.autoScheduleTasks(tasks, context: context)
            scheduledCount = tasks.count
        } catch {
            print("❌ Error auto-scheduling tasks: \(error)")
            throw error
        }

        deselectAll()

        lastOperationResult = OperationResult(
            operation: .autoSchedule,
            affectedCount: scheduledCount,
            success: true
        )

        AnalyticsService.shared.track(.bulkOperation, properties: [
            "operation": "auto_schedule",
            "count": scheduledCount
        ])
    }

    /// Массовое дублирование задач
    func duplicateSelected(context: NSManagedObjectContext) async throws {
        guard !selectedTasks.isEmpty else { return }

        isPerformingOperation = true
        defer { isPerformingOperation = false }

        let taskIds = Array(selectedTasks)
        var duplicatedCount = 0

        for taskId in taskIds {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)

            do {
                if let originalTask = try context.fetch(request).first {
                    let duplicateTask = TaskEntity(context: context)
                    duplicateTask.id = UUID()
                    duplicateTask.title = "\(originalTask.title ?? "Task") (Copy)"
                    duplicateTask.notes = originalTask.notes
                    duplicateTask.priority = originalTask.priority
                    duplicateTask.tags = originalTask.tags
                    duplicateTask.projectID = originalTask.projectID
                    duplicateTask.project = originalTask.project
                    duplicateTask.isCompleted = false
                    duplicateTask.createdAt = Date()
                    duplicateTask.updatedAt = Date()

                    duplicatedCount += 1
                }
            } catch {
                print("❌ Error duplicating task \(taskId): \(error)")
            }
        }

        try context.save()
        deselectAll()

        lastOperationResult = OperationResult(
            operation: .duplicate,
            affectedCount: duplicatedCount,
            success: true
        )

        AnalyticsService.shared.track(.bulkOperation, properties: [
            "operation": "duplicate",
            "count": duplicatedCount
        ])
    }
}

// MARK: - Operation Result Model
struct OperationResult: Identifiable {
    let id = UUID()
    let operation: BulkOperation
    let affectedCount: Int
    let success: Bool
    let errorMessage: String?
    let timestamp = Date()

    init(operation: BulkOperation, affectedCount: Int, success: Bool, errorMessage: String? = nil) {
        self.operation = operation
        self.affectedCount = affectedCount
        self.success = success
        self.errorMessage = errorMessage
    }

    var displayMessage: String {
        if success {
            return "\(operation.displayName): \(affectedCount) task(s) affected"
        } else {
            return "Failed: \(errorMessage ?? "Unknown error")"
        }
    }
}

// MARK: - Bulk Operation Types
enum BulkOperation: String, CaseIterable {
    case complete = "complete"
    case delete = "delete"
    case changePriority = "change_priority"
    case moveToProject = "move_to_project"
    case addTags = "add_tags"
    case setDueDate = "set_due_date"
    case autoSchedule = "auto_schedule"
    case duplicate = "duplicate"

    var displayName: String {
        switch self {
        case .complete: return "Complete"
        case .delete: return "Delete"
        case .changePriority: return "Change Priority"
        case .moveToProject: return "Move to Project"
        case .addTags: return "Add Tags"
        case .setDueDate: return "Set Due Date"
        case .autoSchedule: return "Auto Schedule"
        case .duplicate: return "Duplicate"
        }
    }

    var icon: String {
        switch self {
        case .complete: return "checkmark.circle.fill"
        case .delete: return "trash.fill"
        case .changePriority: return "exclamationmark.3"
        case .moveToProject: return "folder.fill"
        case .addTags: return "tag.fill"
        case .setDueDate: return "calendar.badge.clock"
        case .autoSchedule: return "wand.and.stars"
        case .duplicate: return "doc.on.doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .complete: return .green
        case .delete: return .red
        case .changePriority: return .orange
        case .moveToProject: return .blue
        case .addTags: return .purple
        case .setDueDate: return .cyan
        case .autoSchedule: return .indigo
        case .duplicate: return .gray
        }
    }
}

// MARK: - Errors
enum BulkOperationError: LocalizedError {
    case noTasksSelected
    case projectNotFound
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .noTasksSelected:
            return "No tasks selected for bulk operation"
        case .projectNotFound:
            return "Target project not found"
        case .operationFailed(let message):
            return "Bulk operation failed: \(message)"
        }
    }
}

// MARK: - Analytics Extensions
extension AnalyticsEvent {
    static let bulkOperation = AnalyticsEvent(rawValue: "bulk_operation")!
}
