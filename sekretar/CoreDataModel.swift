import Foundation
import CoreData


extension PersistenceController {
    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // TaskEntity
        let taskEntity = NSEntityDescription()
        taskEntity.name = "TaskEntity"
        taskEntity.managedObjectClassName = NSStringFromClass(TaskEntity.self)

        let id = NSAttributeDescription()
        id.name = "id"; id.attributeType = .UUIDAttributeType; id.isOptional = false

        let title = NSAttributeDescription()
        title.name = "title"; title.attributeType = .stringAttributeType; title.isOptional = false

        let notes = NSAttributeDescription()
        notes.name = "notes"; notes.attributeType = .stringAttributeType; notes.isOptional = true

        let dueDate = NSAttributeDescription()
        dueDate.name = "dueDate"; dueDate.attributeType = .dateAttributeType; dueDate.isOptional = true

        let isCompleted = NSAttributeDescription()
        isCompleted.name = "isCompleted"; isCompleted.attributeType = .booleanAttributeType; isCompleted.defaultValue = false

        let priority = NSAttributeDescription()
        priority.name = "priority"; priority.attributeType = .integer16AttributeType; priority.defaultValue = 1

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"; createdAt.attributeType = .dateAttributeType; createdAt.isOptional = false

        let updatedAt = NSAttributeDescription()
        updatedAt.name = "updatedAt"; updatedAt.attributeType = .dateAttributeType; updatedAt.isOptional = false

        // НОВОЕ: Production features (из ai_calendar_production_plan.md Week 1-2)
        let embeddingVector = NSAttributeDescription()
        embeddingVector.name = "embeddingVector"
        embeddingVector.attributeType = .binaryDataAttributeType
        embeddingVector.isOptional = true
        embeddingVector.allowsExternalBinaryDataStorage = true // Для больших векторов

        let aiMetadata = NSAttributeDescription()
        aiMetadata.name = "aiMetadata"
        aiMetadata.attributeType = .stringAttributeType
        aiMetadata.isOptional = true // JSON with AI-generated insights

        let serverSyncId = NSAttributeDescription()
        serverSyncId.name = "serverSyncId"
        serverSyncId.attributeType = .UUIDAttributeType
        serverSyncId.isOptional = true // For backend sync

        let lastSyncedAt = NSAttributeDescription()
        lastSyncedAt.name = "lastSyncedAt"
        lastSyncedAt.attributeType = .dateAttributeType
        lastSyncedAt.isOptional = true

        let conflictVersion = NSAttributeDescription()
        conflictVersion.name = "conflictVersion"
        conflictVersion.attributeType = .integer32AttributeType
        conflictVersion.defaultValue = 1 // For conflict resolution

        taskEntity.properties = [
            id, title, notes, dueDate, isCompleted, priority, createdAt, updatedAt,
            // Production fields:
            embeddingVector, aiMetadata, serverSyncId, lastSyncedAt, conflictVersion
        ]

        // EventEntity
        let eventEntity = NSEntityDescription()
        eventEntity.name = "EventEntity"
        eventEntity.managedObjectClassName = NSStringFromClass(EventEntity.self)

        let eId = NSAttributeDescription(); eId.name = "id"; eId.attributeType = .UUIDAttributeType; eId.isOptional = false
        let eTitle = NSAttributeDescription(); eTitle.name = "title"; eTitle.attributeType = .stringAttributeType; eTitle.isOptional = false
        let startDate = NSAttributeDescription(); startDate.name = "startDate"; startDate.attributeType = .dateAttributeType; startDate.isOptional = false
        let endDate = NSAttributeDescription(); endDate.name = "endDate"; endDate.attributeType = .dateAttributeType; endDate.isOptional = false
        let isAllDay = NSAttributeDescription(); isAllDay.name = "isAllDay"; isAllDay.attributeType = .booleanAttributeType; isAllDay.defaultValue = false
        let eNotes = NSAttributeDescription(); eNotes.name = "notes"; eNotes.attributeType = .stringAttributeType; eNotes.isOptional = true
        let eventKitId = NSAttributeDescription(); eventKitId.name = "eventKitId"; eventKitId.attributeType = .stringAttributeType; eventKitId.isOptional = true

        // Production features для events
        let eEmbeddingVector = NSAttributeDescription()
        eEmbeddingVector.name = "embeddingVector"
        eEmbeddingVector.attributeType = .binaryDataAttributeType
        eEmbeddingVector.isOptional = true
        eEmbeddingVector.allowsExternalBinaryDataStorage = true

        let eAiMetadata = NSAttributeDescription()
        eAiMetadata.name = "aiMetadata"
        eAiMetadata.attributeType = .stringAttributeType
        eAiMetadata.isOptional = true

        let eServerSyncId = NSAttributeDescription()
        eServerSyncId.name = "serverSyncId"
        eServerSyncId.attributeType = .UUIDAttributeType
        eServerSyncId.isOptional = true

        let eLastSyncedAt = NSAttributeDescription()
        eLastSyncedAt.name = "lastSyncedAt"
        eLastSyncedAt.attributeType = .dateAttributeType
        eLastSyncedAt.isOptional = true

        let eConflictVersion = NSAttributeDescription()
        eConflictVersion.name = "conflictVersion"
        eConflictVersion.attributeType = .integer32AttributeType
        eConflictVersion.defaultValue = 1

        eventEntity.properties = [
            eId, eTitle, startDate, endDate, isAllDay, eNotes, eventKitId,
            // Production fields:
            eEmbeddingVector, eAiMetadata, eServerSyncId, eLastSyncedAt, eConflictVersion
        ]

        // ProjectEntity
        let projectEntity = NSEntityDescription()
        projectEntity.name = "ProjectEntity"
        projectEntity.managedObjectClassName = NSStringFromClass(ProjectEntity.self)
        
        let pId = NSAttributeDescription(); pId.name = "id"; pId.attributeType = .UUIDAttributeType; pId.isOptional = false
        let pTitle = NSAttributeDescription(); pTitle.name = "title"; pTitle.attributeType = .stringAttributeType; pTitle.isOptional = false
        let pColor = NSAttributeDescription(); pColor.name = "color"; pColor.attributeType = .stringAttributeType; pColor.isOptional = true
        let pCreatedAt = NSAttributeDescription(); pCreatedAt.name = "createdAt"; pCreatedAt.attributeType = .dateAttributeType; pCreatedAt.isOptional = false
        
        projectEntity.properties = [pId, pTitle, pColor, pCreatedAt]

        // UserPrefEntity
        let userPrefEntity = NSEntityDescription()
        userPrefEntity.name = "UserPrefEntity"
        userPrefEntity.managedObjectClassName = NSStringFromClass(UserPrefEntity.self)
        
        let upId = NSAttributeDescription(); upId.name = "id"; upId.attributeType = .UUIDAttributeType; upId.isOptional = false
        let upKey = NSAttributeDescription(); upKey.name = "key"; upKey.attributeType = .stringAttributeType; upKey.isOptional = false
        let upValue = NSAttributeDescription(); upValue.name = "value"; upValue.attributeType = .stringAttributeType; upValue.isOptional = true
        let upUpdatedAt = NSAttributeDescription(); upUpdatedAt.name = "updatedAt"; upUpdatedAt.attributeType = .dateAttributeType; upUpdatedAt.isOptional = false
        
        userPrefEntity.properties = [upId, upKey, upValue, upUpdatedAt]

        // AIActionLogEntity
        let aiActionLogEntity = NSEntityDescription()
        aiActionLogEntity.name = "AIActionLogEntity"
        aiActionLogEntity.managedObjectClassName = NSStringFromClass(AIActionLogEntity.self)
        
        let alId = NSAttributeDescription(); alId.name = "id"; alId.attributeType = .UUIDAttributeType; alId.isOptional = false
        let alAction = NSAttributeDescription(); alAction.name = "action"; alAction.attributeType = .stringAttributeType; alAction.isOptional = false
        let alPayload = NSAttributeDescription(); alPayload.name = "payload"; alPayload.attributeType = .stringAttributeType; alPayload.isOptional = true
        let alCreatedAt = NSAttributeDescription(); alCreatedAt.name = "createdAt"; alCreatedAt.attributeType = .dateAttributeType; alCreatedAt.isOptional = false
        let alConfidence = NSAttributeDescription(); alConfidence.name = "confidence"; alConfidence.attributeType = .floatAttributeType; alConfidence.isOptional = false
        let alRequires = NSAttributeDescription(); alRequires.name = "requiresConfirmation"; alRequires.attributeType = .booleanAttributeType; alRequires.defaultValue = false
        let alExecuted = NSAttributeDescription(); alExecuted.name = "isExecuted"; alExecuted.attributeType = .booleanAttributeType; alExecuted.defaultValue = false
        
        aiActionLogEntity.properties = [alId, alAction, alPayload, alCreatedAt, alConfidence, alRequires, alExecuted]

        // Task-Project relationship
        let taskToProject = NSRelationshipDescription()
        taskToProject.name = "project"
        taskToProject.destinationEntity = projectEntity
        taskToProject.isOptional = true
        taskToProject.maxCount = 1
        
        let projectToTasks = NSRelationshipDescription()
        projectToTasks.name = "tasks"
        projectToTasks.destinationEntity = taskEntity
        projectToTasks.isOptional = true
        projectToTasks.maxCount = 0 // to-many
        
        taskToProject.inverseRelationship = projectToTasks
        projectToTasks.inverseRelationship = taskToProject
        
        taskEntity.properties.append(taskToProject)
        projectEntity.properties.append(projectToTasks)

        model.entities = [taskEntity, eventEntity, projectEntity, userPrefEntity, aiActionLogEntity]
        return model
    }
}
