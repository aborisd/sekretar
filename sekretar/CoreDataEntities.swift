import Foundation
import CoreData

@objc(TaskEntity)
final class TaskEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<TaskEntity> {
        NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
    }

    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var notes: String?
    @NSManaged var dueDate: Date?
    @NSManaged var reminderDate: Date?
    @NSManaged var isCompleted: Bool
    @NSManaged var priority: Int16
    @NSManaged var tags: String?
    @NSManaged var projectID: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var project: ProjectEntity?
}

@objc(EventEntity)
final class EventEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<EventEntity> {
        NSFetchRequest<EventEntity>(entityName: "EventEntity")
    }

    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var startDate: Date?
    @NSManaged var endDate: Date?
    @NSManaged var isAllDay: Bool
    @NSManaged var notes: String?
    @NSManaged var eventKitId: String?
}

@objc(ProjectEntity)
final class ProjectEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ProjectEntity> {
        NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
    }

    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var color: String?
    @NSManaged var createdAt: Date?
    @NSManaged var tasks: Set<TaskEntity>?
}

@objc(UserPrefEntity)
final class UserPrefEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<UserPrefEntity> {
        NSFetchRequest<UserPrefEntity>(entityName: "UserPrefEntity")
    }

    @NSManaged var id: UUID?
    @NSManaged var key: String?
    @NSManaged var value: String?
    @NSManaged var updatedAt: Date?
}

@objc(AIActionLogEntity)
final class AIActionLogEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<AIActionLogEntity> {
        NSFetchRequest<AIActionLogEntity>(entityName: "AIActionLogEntity")
    }

    @NSManaged var id: UUID?
    @NSManaged var action: String?
    @NSManaged var payload: String?
    @NSManaged var confidence: Float
    @NSManaged var requiresConfirmation: Bool
    @NSManaged var isExecuted: Bool
    @NSManaged var createdAt: Date?
    @NSManaged var executedAt: Date?
}
