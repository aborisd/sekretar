import Foundation
import CoreData
import Network
import SwiftUI

// MARK: - Offline Sync Service
/// Оффлайн-очереди и синхронизация (BRD строки 96, 465)
/// - Маскирование операций при отсутствии сети
/// - Автоматическая синхронизация при возврате в онлайн
@MainActor
final class OfflineSyncService: ObservableObject {
    static let shared = OfflineSyncService()

    @Published var isOnline = true
    @Published var pendingOperationsCount = 0
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [SyncError] = []

    private let context: NSManagedObjectContext
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.sekretar.sync")
    private var pendingOperations: [PendingOperation] = []

    private init() {
        self.context = PersistenceController.shared.container.viewContext
        setupNetworkMonitoring()
        loadPendingOperations()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied

                // Автоматическая синхронизация при возврате в онлайн
                if wasOffline && path.status == .satisfied {
                    print("📡 Network restored, triggering auto-sync")
                    await self?.syncPendingOperations()
                }
            }
        }
        monitor.start(queue: queue)
    }

    // MARK: - Pending Operations Management

    /// Добавляет операцию в оффлайн-очередь
    func queueOperation(_ operation: PendingOperation) {
        pendingOperations.append(operation)
        pendingOperationsCount = pendingOperations.count
        savePendingOperations()

        print("📥 Queued operation: \(operation.type.rawValue) [\(operation.id)]")

        AnalyticsService.shared.track(.operationQueued, properties: [
            "type": operation.type.rawValue,
            "is_online": isOnline
        ])

        // Если онлайн, сразу синхронизируем
        if isOnline {
            Task {
                await syncPendingOperations()
            }
        }
    }

    /// Синхронизирует все pending операции
    func syncPendingOperations() async {
        guard !isSyncing, !pendingOperations.isEmpty else { return }

        isSyncing = true
        defer { isSyncing = false }

        print("🔄 Starting sync: \(pendingOperations.count) pending operations")

        var successCount = 0
        var failureCount = 0
        var operationsToRetry: [PendingOperation] = []

        for operation in pendingOperations {
            do {
                try await executeOperation(operation)
                successCount += 1
                print("✅ Synced: \(operation.type.rawValue) [\(operation.id)]")
            } catch {
                failureCount += 1
                print("❌ Sync failed: \(operation.type.rawValue) [\(operation.id)]: \(error)")

                // Retry logic
                let updatedOperation = operation.incrementRetryCount()
                if updatedOperation.retryCount < 3 {
                    operationsToRetry.append(updatedOperation)
                } else {
                    // Max retries exceeded, log error
                    let syncError = SyncError(
                        operation: operation,
                        error: error.localizedDescription,
                        timestamp: Date()
                    )
                    syncErrors.append(syncError)
                }
            }
        }

        // Update pending operations list
        pendingOperations = operationsToRetry
        pendingOperationsCount = pendingOperations.count
        savePendingOperations()

        lastSyncDate = Date()

        print("🔄 Sync completed: \(successCount) success, \(failureCount) failures")

        AnalyticsService.shared.track(.syncCompleted, properties: [
            "success_count": successCount,
            "failure_count": failureCount,
            "pending_count": pendingOperationsCount
        ])
    }

    /// Выполняет отдельную операцию
    private func executeOperation(_ operation: PendingOperation) async throws {
        switch operation.type {
        case .createTask:
            try await executeCreateTask(operation)
        case .updateTask:
            try await executeUpdateTask(operation)
        case .deleteTask:
            try await executeDeleteTask(operation)
        case .createEvent:
            try await executeCreateEvent(operation)
        case .updateEvent:
            try await executeUpdateEvent(operation)
        case .deleteEvent:
            try await executeDeleteEvent(operation)
        case .aiAction:
            try await executeAIAction(operation)
        }
    }

    // MARK: - Operation Execution

    private func executeCreateTask(_ operation: PendingOperation) async throws {
        guard let taskId = operation.entityId,
              let payload = operation.payload else {
            throw SyncServiceError.invalidPayload
        }

        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)

        let exists = try await context.perform {
            let results = try self.context.fetch(request)
            return !results.isEmpty
        }

        if exists {
            // Task already created locally, just mark as synced
            print("✅ Task already exists, marking as synced")
        } else {
            // Create task from payload
            await context.perform {
                let task = TaskEntity(context: self.context)
                task.id = taskId
                task.title = payload["title"] as? String
                task.notes = payload["notes"] as? String
                task.priority = payload["priority"] as? Int16 ?? 0
                task.isCompleted = payload["isCompleted"] as? Bool ?? false
                task.createdAt = Date()
                task.updatedAt = Date()

                try? self.context.save()
            }
        }
    }

    private func executeUpdateTask(_ operation: PendingOperation) async throws {
        guard let taskId = operation.entityId,
              let payload = operation.payload else {
            throw SyncServiceError.invalidPayload
        }

        try await context.perform {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)

            guard let task = try self.context.fetch(request).first else {
                throw SyncServiceError.entityNotFound
            }

            if let title = payload["title"] as? String {
                task.title = title
            }
            if let notes = payload["notes"] as? String {
                task.notes = notes
            }
            if let priority = payload["priority"] as? Int16 {
                task.priority = priority
            }
            if let isCompleted = payload["isCompleted"] as? Bool {
                task.isCompleted = isCompleted
            }

            task.updatedAt = Date()
            try self.context.save()
        }
    }

    private func executeDeleteTask(_ operation: PendingOperation) async throws {
        guard let taskId = operation.entityId else {
            throw SyncServiceError.invalidPayload
        }

        try await context.perform {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)

            guard let task = try self.context.fetch(request).first else {
                // Already deleted, consider success
                return
            }

            self.context.delete(task)
            try self.context.save()
        }
    }

    private func executeCreateEvent(_ operation: PendingOperation) async throws {
        guard let eventId = operation.entityId,
              let payload = operation.payload else {
            throw SyncServiceError.invalidPayload
        }

        try await context.perform {
            let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", eventId as CVarArg)

            let exists = (try? self.context.fetch(request).first) != nil

            if !exists {
                let event = EventEntity(context: self.context)
                event.id = eventId
                event.title = payload["title"] as? String
                event.notes = payload["notes"] as? String
                event.isAllDay = payload["isAllDay"] as? Bool ?? false

                if let startTimestamp = payload["startDate"] as? TimeInterval {
                    event.startDate = Date(timeIntervalSince1970: startTimestamp)
                }
                if let endTimestamp = payload["endDate"] as? TimeInterval {
                    event.endDate = Date(timeIntervalSince1970: endTimestamp)
                }

                try self.context.save()
            }
        }
    }

    private func executeUpdateEvent(_ operation: PendingOperation) async throws {
        guard let eventId = operation.entityId,
              let payload = operation.payload else {
            throw SyncServiceError.invalidPayload
        }

        try await context.perform {
            let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", eventId as CVarArg)

            guard let event = try self.context.fetch(request).first else {
                throw SyncServiceError.entityNotFound
            }

            if let title = payload["title"] as? String {
                event.title = title
            }
            if let notes = payload["notes"] as? String {
                event.notes = notes
            }
            if let isAllDay = payload["isAllDay"] as? Bool {
                event.isAllDay = isAllDay
            }

            try self.context.save()
        }
    }

    private func executeDeleteEvent(_ operation: PendingOperation) async throws {
        guard let eventId = operation.entityId else {
            throw SyncServiceError.invalidPayload
        }

        try await context.perform {
            let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", eventId as CVarArg)

            guard let event = try self.context.fetch(request).first else {
                return
            }

            self.context.delete(event)
            try self.context.save()
        }
    }

    private func executeAIAction(_ operation: PendingOperation) async throws {
        // AI actions are already executed locally, just mark as synced
        print("✅ AI action synced")
    }

    // MARK: - Persistence

    private func savePendingOperations() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(pendingOperations) {
            UserDefaults.standard.set(data, forKey: "pendingOperations")
        }
    }

    private func loadPendingOperations() {
        guard let data = UserDefaults.standard.data(forKey: "pendingOperations"),
              let operations = try? JSONDecoder().decode([PendingOperation].self, from: data) else {
            return
        }

        pendingOperations = operations
        pendingOperationsCount = operations.count
        print("📥 Loaded \(operations.count) pending operations")
    }

    // MARK: - Manual Control

    func clearSyncErrors() {
        syncErrors.removeAll()
    }

    func retryFailedOperations() async {
        await syncPendingOperations()
    }
}

// MARK: - Models

struct PendingOperation: Codable, Identifiable {
    let id: UUID
    let type: OperationType
    let entityId: UUID?
    let payload: [String: AnyCodable]?
    let timestamp: Date
    let retryCount: Int

    init(
        id: UUID = UUID(),
        type: OperationType,
        entityId: UUID? = nil,
        payload: [String: Any]? = nil,
        timestamp: Date = Date(),
        retryCount: Int = 0
    ) {
        self.id = id
        self.type = type
        self.entityId = entityId
        self.payload = payload?.mapValues { AnyCodable($0) }
        self.timestamp = timestamp
        self.retryCount = retryCount
    }

    func incrementRetryCount() -> PendingOperation {
        PendingOperation(
            id: id,
            type: type,
            entityId: entityId,
            payload: payload?.mapValues { $0.value },
            timestamp: timestamp,
            retryCount: retryCount + 1
        )
    }

    enum OperationType: String, Codable {
        case createTask
        case updateTask
        case deleteTask
        case createEvent
        case updateEvent
        case deleteEvent
        case aiAction
    }
}

struct SyncError: Identifiable {
    let id = UUID()
    let operation: PendingOperation
    let error: String
    let timestamp: Date
}

// MARK: - AnyCodable Helper
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let int16Value as Int16:
            try container.encode(int16Value)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Errors
enum SyncServiceError: LocalizedError {
    case invalidPayload
    case entityNotFound
    case networkUnavailable
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Invalid operation payload"
        case .entityNotFound:
            return "Entity not found for sync"
        case .networkUnavailable:
            return "Network is not available"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}

// MARK: - Analytics Extensions
extension AnalyticsEvent {
    static let operationQueued = AnalyticsEvent(rawValue: "operation_queued")!
    static let syncCompleted = AnalyticsEvent(rawValue: "sync_completed")!
}
