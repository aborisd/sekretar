import Foundation
import CoreData
import BackgroundTasks

/// Sync conflict type
struct SyncConflict: Identifiable {
    let id = UUID()
    let entityType: String  // "task" or "event"
    let entityId: UUID
    let localVersion: Int
    let serverVersion: Int
    let localUpdatedAt: Date
    let serverUpdatedAt: Date
    let localData: [String: Any]
    let serverData: [String: Any]
}

/// Sync conflict resolution
enum ConflictResolution {
    case useLocal
    case useServer
    case merge([String: Any])
}

/// Sync statistics
struct SyncStats {
    var tasksPushed: Int = 0
    var tasksPulled: Int = 0
    var eventsPushed: Int = 0
    var eventsPulled: Int = 0
    var conflictsDetected: Int = 0
    var conflictsResolved: Int = 0
    var errors: [String] = []

    var totalPushed: Int { tasksPushed + eventsPushed }
    var totalPulled: Int { tasksPulled + eventsPulled }
}

/// Sync request models
struct SyncPushRequest: Codable {
    struct TaskData: Codable {
        let id: String
        let title: String
        let description: String?
        let isCompleted: Bool
        let dueDate: Date?
        let priority: String
        let tags: [String]
        let version: Int
        let createdAt: Date
        let updatedAt: Date
    }

    struct EventData: Codable {
        let id: String
        let title: String
        let description: String?
        let startDate: Date
        let endDate: Date
        let location: String?
        let isAllDay: Bool
        let tags: [String]
        let version: Int
        let createdAt: Date
        let updatedAt: Date
    }

    let tasks: [TaskData]
    let events: [EventData]
    let lastSyncAt: Date?
}

struct SyncPushResponse: Codable {
    let success: Bool
    let conflicts: [ConflictData]?
    let message: String?

    struct ConflictData: Codable {
        let entityType: String
        let entityId: String
        let localVersion: Int
        let serverVersion: Int
    }
}

struct SyncPullResponse: Codable {
    let tasks: [SyncPushRequest.TaskData]
    let events: [SyncPushRequest.EventData]
    let deletedTaskIds: [String]
    let deletedEventIds: [String]
    let serverTimestamp: Date
}

/// Sync service for background synchronization
actor SyncService: ObservableObject {
    static let shared = SyncService()

    @MainActor @Published private(set) var isSyncing = false
    @MainActor @Published private(set) var lastSyncDate: Date?
    @MainActor @Published private(set) var pendingConflicts: [SyncConflict] = []
    @MainActor @Published private(set) var lastSyncStats: SyncStats?

    private let context: NSManagedObjectContext
    private let syncInterval: TimeInterval = 15 * 60  // 15 minutes
    private var syncTimer: Timer?

    private let bgTaskIdentifier = "com.sekretar.backgroundSync"

    private init() {
        self.context = PersistenceController.shared.container.viewContext

        // Load last sync date
        if let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            Task { @MainActor in
                self.lastSyncDate = lastSync
            }
        }

        // Register background task
        registerBackgroundTask()
    }

    // MARK: - Sync Operations

    /// Perform full sync (push + pull)
    func sync(force: Bool = false) async throws -> SyncStats {
        // Check authentication
        guard await AuthManager.shared.isAuthenticated() else {
            print("⚠️ [Sync] Skipping sync - not authenticated")
            return SyncStats()
        }

        // Check if sync needed
        if !force, let lastSync = await getLastSyncDate() {
            let timeSinceSync = Date().timeIntervalSince(lastSync)
            if timeSinceSync < syncInterval {
                print("⏭️ [Sync] Skipping sync - last sync \(Int(timeSinceSync))s ago")
                return SyncStats()
            }
        }

        await MainActor.run { isSyncing = true }
        defer { Task { @MainActor in isSyncing = false } }

        print("🔄 [Sync] Starting sync...")

        var stats = SyncStats()

        do {
            // Step 1: Push local changes
            let pushStats = try await pushChanges()
            stats.tasksPushed = pushStats.tasksPushed
            stats.eventsPushed = pushStats.eventsPushed
            stats.conflictsDetected = pushStats.conflictsDetected

            // Step 2: Pull remote changes
            let pullStats = try await pullChanges()
            stats.tasksPulled = pullStats.tasksPulled
            stats.eventsPulled = pullStats.eventsPulled

            // Update last sync date
            await setLastSyncDate(Date())

            await MainActor.run {
                lastSyncStats = stats
            }

            print("✅ [Sync] Completed - pushed: \(stats.totalPushed), pulled: \(stats.totalPulled), conflicts: \(stats.conflictsDetected)")

            return stats
        } catch {
            print("❌ [Sync] Failed: \(error)")
            stats.errors.append(error.localizedDescription)
            throw error
        }
    }

    /// Push local changes to server
    private func pushChanges() async throws -> SyncStats {
        var stats = SyncStats()

        // Fetch modified entities since last sync
        let lastSync = await getLastSyncDate()

        let tasks = try await fetchModifiedTasks(since: lastSync)
        let events = try await fetchModifiedEvents(since: lastSync)

        guard !tasks.isEmpty || !events.isEmpty else {
            print("ℹ️ [Sync] No local changes to push")
            return stats
        }

        // Convert to request format
        let taskData = tasks.map { convertTaskToSyncData($0) }
        let eventData = events.map { convertEventToSyncData($0) }

        let request = SyncPushRequest(
            tasks: taskData,
            events: eventData,
            lastSyncAt: lastSync
        )

        // Push to server
        let response: SyncPushResponse = try await NetworkService.shared.post(
            "/sync/push",
            body: request,
            requiresAuth: true
        )

        stats.tasksPushed = taskData.count
        stats.eventsPushed = eventData.count

        // Handle conflicts
        if let conflicts = response.conflicts, !conflicts.isEmpty {
            stats.conflictsDetected = conflicts.count
            print("⚠️ [Sync] Detected \(conflicts.count) conflicts")
            // Store conflicts for resolution
            await storeConflicts(conflicts)
        }

        return stats
    }

    /// Pull remote changes from server
    private func pullChanges() async throws -> SyncStats {
        var stats = SyncStats()

        let lastSync = await getLastSyncDate()

        // Build query params
        var endpoint = "/sync/pull"
        if let lastSync = lastSync {
            let timestamp = ISO8601DateFormatter().string(from: lastSync)
            endpoint += "?since=\(timestamp)"
        }

        // Pull from server
        let response: SyncPullResponse = try await NetworkService.shared.get(
            endpoint,
            requiresAuth: true
        )

        // Apply changes to local database
        try await context.perform {
            // Delete deleted entities
            try self.deleteEntities(taskIds: response.deletedTaskIds, eventIds: response.deletedEventIds)

            // Upsert tasks
            for taskData in response.tasks {
                try self.upsertTask(taskData)
                stats.tasksPulled += 1
            }

            // Upsert events
            for eventData in response.events {
                try self.upsertEvent(eventData)
                stats.eventsPulled += 1
            }

            // Save context
            if self.context.hasChanges {
                try self.context.save()
            }
        }

        return stats
    }

    // MARK: - Conflict Resolution

    /// Resolve a conflict
    func resolveConflict(_ conflict: SyncConflict, resolution: ConflictResolution) async throws {
        switch resolution {
        case .useLocal:
            // Mark local version as authoritative
            try await forceUploadEntity(id: conflict.entityId, type: conflict.entityType)

        case .useServer:
            // Re-pull from server to overwrite local
            try await forceDownloadEntity(id: conflict.entityId, type: conflict.entityType)

        case .merge(let mergedData):
            // Apply merged data to local and push
            try await applyMergedData(id: conflict.entityId, type: conflict.entityType, data: mergedData)
        }

        // Remove conflict from pending list
        await MainActor.run {
            pendingConflicts.removeAll { $0.id == conflict.id }
        }
    }

    private func forceUploadEntity(id: UUID, type: String) async throws {
        // Implementation would force-push this specific entity
        print("🔼 [Sync] Force uploading \(type) \(id)")
    }

    private func forceDownloadEntity(id: UUID, type: String) async throws {
        // Implementation would force-pull this specific entity
        print("🔽 [Sync] Force downloading \(type) \(id)")
    }

    private func applyMergedData(id: UUID, type: String, data: [String: Any]) async throws {
        // Implementation would apply merged data and push
        print("🔀 [Sync] Applying merged data for \(type) \(id)")
    }

    private func storeConflicts(_ conflicts: [SyncPushResponse.ConflictData]) async {
        // Convert to SyncConflict objects and store
        // For now, just print
        print("⚠️ [Sync] Storing \(conflicts.count) conflicts for user resolution")
    }

    // MARK: - Background Sync

    /// Register background task
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: bgTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
    }

    /// Schedule next background sync
    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: syncInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 [Sync] Scheduled background sync")
        } catch {
            print("❌ [Sync] Failed to schedule background sync: \(error)")
        }
    }

    /// Handle background sync task
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        print("🌙 [Sync] Background sync triggered")

        // Schedule next sync
        scheduleBackgroundSync()

        Task {
            do {
                _ = try await sync(force: false)
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ [Sync] Background sync failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }

        // Set expiration handler
        task.expirationHandler = {
            print("⏰ [Sync] Background sync expired")
        }
    }

    // MARK: - Helpers

    private func fetchModifiedTasks(since date: Date?) async throws -> [NSManagedObject] {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "TaskEntity")
            if let date = date {
                request.predicate = NSPredicate(format: "updatedAt > %@", date as NSDate)
            }
            return try self.context.fetch(request)
        }
    }

    private func fetchModifiedEvents(since date: Date?) async throws -> [NSManagedObject] {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "EventEntity")
            if let date = date {
                request.predicate = NSPredicate(format: "updatedAt > %@", date as NSDate)
            }
            return try self.context.fetch(request)
        }
    }

    private func convertTaskToSyncData(_ task: NSManagedObject) -> SyncPushRequest.TaskData {
        let id = task.value(forKey: "id") as? UUID ?? UUID()
        return SyncPushRequest.TaskData(
            id: id.uuidString,
            title: task.value(forKey: "title") as? String ?? "",
            description: task.value(forKey: "taskDescription") as? String,
            isCompleted: task.value(forKey: "isCompleted") as? Bool ?? false,
            dueDate: task.value(forKey: "dueDate") as? Date,
            priority: task.value(forKey: "priority") as? String ?? "medium",
            tags: (task.value(forKey: "tags") as? String)?.components(separatedBy: ",") ?? [],
            version: task.value(forKey: "version") as? Int ?? 0,
            createdAt: task.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: task.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private func convertEventToSyncData(_ event: NSManagedObject) -> SyncPushRequest.EventData {
        let id = event.value(forKey: "id") as? UUID ?? UUID()
        return SyncPushRequest.EventData(
            id: id.uuidString,
            title: event.value(forKey: "title") as? String ?? "",
            description: event.value(forKey: "eventDescription") as? String,
            startDate: event.value(forKey: "startDate") as? Date ?? Date(),
            endDate: event.value(forKey: "endDate") as? Date ?? Date(),
            location: event.value(forKey: "location") as? String,
            isAllDay: event.value(forKey: "isAllDay") as? Bool ?? false,
            tags: (event.value(forKey: "tags") as? String)?.components(separatedBy: ",") ?? [],
            version: event.value(forKey: "version") as? Int ?? 0,
            createdAt: event.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: event.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private func deleteEntities(taskIds: [String], eventIds: [String]) throws {
        // Delete tasks
        for idString in taskIds {
            guard let uuid = UUID(uuidString: idString) else { continue }
            let request = NSFetchRequest<NSManagedObject>(entityName: "TaskEntity")
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            if let task = try context.fetch(request).first {
                context.delete(task)
            }
        }

        // Delete events
        for idString in eventIds {
            guard let uuid = UUID(uuidString: idString) else { continue }
            let request = NSFetchRequest<NSManagedObject>(entityName: "EventEntity")
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            if let event = try context.fetch(request).first {
                context.delete(event)
            }
        }
    }

    private func upsertTask(_ data: SyncPushRequest.TaskData) throws {
        guard let uuid = UUID(uuidString: data.id) else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "TaskEntity")
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)

        let task = try context.fetch(request).first ?? NSEntityDescription.insertNewObject(forEntityName: "TaskEntity", into: context)

        task.setValue(uuid, forKey: "id")
        task.setValue(data.title, forKey: "title")
        task.setValue(data.description, forKey: "taskDescription")
        task.setValue(data.isCompleted, forKey: "isCompleted")
        task.setValue(data.dueDate, forKey: "dueDate")
        task.setValue(data.priority, forKey: "priority")
        task.setValue(data.tags.joined(separator: ","), forKey: "tags")
        task.setValue(Int64(data.version), forKey: "version")
        task.setValue(data.createdAt, forKey: "createdAt")
        task.setValue(data.updatedAt, forKey: "updatedAt")
    }

    private func upsertEvent(_ data: SyncPushRequest.EventData) throws {
        guard let uuid = UUID(uuidString: data.id) else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "EventEntity")
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)

        let event = try context.fetch(request).first ?? NSEntityDescription.insertNewObject(forEntityName: "EventEntity", into: context)

        event.setValue(uuid, forKey: "id")
        event.setValue(data.title, forKey: "title")
        event.setValue(data.description, forKey: "eventDescription")
        event.setValue(data.startDate, forKey: "startDate")
        event.setValue(data.endDate, forKey: "endDate")
        event.setValue(data.location, forKey: "location")
        event.setValue(data.isAllDay, forKey: "isAllDay")
        event.setValue(data.tags.joined(separator: ","), forKey: "tags")
        event.setValue(Int64(data.version), forKey: "version")
        event.setValue(data.createdAt, forKey: "createdAt")
        event.setValue(data.updatedAt, forKey: "updatedAt")
    }

    private func getLastSyncDate() async -> Date? {
        return UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }

    private func setLastSyncDate(_ date: Date) async {
        UserDefaults.standard.set(date, forKey: "lastSyncDate")
        await MainActor.run {
            lastSyncDate = date
        }
    }
}
