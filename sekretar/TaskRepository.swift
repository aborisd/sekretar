import Foundation
import CoreData

protocol TaskRepository {
    @discardableResult func create(title: String, notes: String?, dueDate: Date?, priority: Int16) async throws -> TaskEntity
    func update(_ task: TaskEntity, title: String, notes: String?, dueDate: Date?, priority: Int16) async throws
    func toggleComplete(_ task: TaskEntity) async throws
    func delete(_ task: TaskEntity) async throws
}

final class TaskRepositoryCD: TaskRepository {
    private let context: NSManagedObjectContext
    init(context: NSManagedObjectContext) { self.context = context }

    @discardableResult
    func create(title: String, notes: String?, dueDate: Date?, priority: Int16) async throws -> TaskEntity {
        try await context.perform {
            let t = TaskEntity(context: self.context)
            t.id = UUID(); t.title = title; t.notes = notes
            t.dueDate = dueDate; t.priority = priority
            t.isCompleted = false
            let now = Date(); t.createdAt = now; t.updatedAt = now
            try self.context.save()
            return t
        }
    }

    func update(_ task: TaskEntity, title: String, notes: String?, dueDate: Date?, priority: Int16) async throws {
        try await context.perform {
            task.title = title; task.notes = notes; task.dueDate = dueDate; task.priority = priority
            task.updatedAt = Date()
            try self.context.save()
        }
    }

    func toggleComplete(_ task: TaskEntity) async throws {
        try await context.perform {
            task.isCompleted.toggle()
            task.updatedAt = Date()
            try self.context.save()
        }
    }

    func delete(_ task: TaskEntity) async throws {
        try await context.perform {
            self.context.delete(task)
            try self.context.save()
        }
    }
}

