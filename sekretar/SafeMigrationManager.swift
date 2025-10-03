import Foundation
import CoreData

// MARK: - Safe Migration Manager (из ai_calendar_production_plan_v4.md, Section 3)

/// Безопасная миграция данных с поэтапным rollback
class SafeMigrationManager {

    private let persistenceController: PersistenceController
    private let readinessChecker: MigrationReadinessChecker
    private let batchSize = 100 // Размер батча для миграции

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.readinessChecker = MigrationReadinessChecker(persistenceController: persistenceController)
    }

    // MARK: - Main Migration

    /// Полная миграция с автоматическим rollback при ошибках
    func migrate(progressHandler: @escaping (MigrationProgress) -> Void) async throws {
        print("🚀 [Migration] Starting safe migration...")

        // 1. Pre-flight проверка
        print("  Step 1: Pre-flight checks...")
        let readinessReport = try await readinessChecker.assessReadiness()

        guard readinessReport.canProceed else {
            print("❌ [Migration] Not ready to proceed!")
            print(readinessReport.summary)
            throw MigrationError.notReady(report: readinessReport)
        }

        print("  ✓ Pre-flight checks passed")

        // 2. Создание точки восстановления
        print("  Step 2: Creating backup...")
        let backupId = try await createFullBackup()
        print("  ✓ Backup created: \(backupId)")

        do {
            // 3. Миграция по батчам
            print("  Step 3: Migrating data in batches...")
            let batches = try await prepareMigrationBatches()
            print("  ✓ Prepared \(batches.count) batches")

            var completedBatches = 0
            let totalBatches = batches.count

            for (index, batch) in batches.enumerated() {
                print("    Processing batch \(index + 1)/\(totalBatches)...")

                // Прогресс
                let progress = MigrationProgress(
                    phase: .migrating,
                    current: index,
                    total: totalBatches,
                    message: "Migrating batch \(index + 1)/\(totalBatches)"
                )
                progressHandler(progress)

                do {
                    // Миграция батча
                    try await migrateBatch(batch)

                    // Валидация батча
                    try await validateBatch(batch)

                    completedBatches += 1

                } catch {
                    // Автоматический откат при ошибке
                    print("❌ [Migration] Batch \(index) failed: \(error)")
                    print("  Rolling back to backup...")

                    try await rollbackToBackup(backupId)

                    throw MigrationError.batchFailed(batchIndex: index, error: error)
                }
            }

            // 4. Финальная валидация
            print("  Step 4: Final validation...")
            try await performFullValidation()
            print("  ✓ Validation passed")

            // 5. Cleanup старого backup (опционально сохранить)
            print("  Step 5: Cleanup...")
            await cleanupOldBackups(keepRecent: 3)
            print("  ✓ Cleanup complete")

            print("✅ [Migration] Successfully completed!")

            progressHandler(MigrationProgress(
                phase: .completed,
                current: totalBatches,
                total: totalBatches,
                message: "Migration completed successfully"
            ))

        } catch {
            print("❌ [Migration] Failed with error: \(error)")
            throw error
        }
    }

    // MARK: - Backup Management

    private func createFullBackup() async throws -> String {
        let backupId = UUID().uuidString
        let context = persistenceController.container.viewContext

        // Путь для backup
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw MigrationError.backupFailed("Cannot access documents directory")
        }

        let backupPath = documentsPath.appendingPathComponent("backups")
        try FileManager.default.createDirectory(at: backupPath, withIntermediateDirectories: true)

        let backupFile = backupPath.appendingPathComponent("\(backupId).sqlite")

        // Копируем SQLite файл
        if let storeURL = persistenceController.container.persistentStoreDescriptions.first?.url {
            try FileManager.default.copyItem(at: storeURL, to: backupFile)

            // Копируем WAL и SHM файлы если есть
            let walURL = storeURL.appendingPathExtension("wal")
            let shmURL = storeURL.appendingPathExtension("shm")

            if FileManager.default.fileExists(atPath: walURL.path) {
                try? FileManager.default.copyItem(
                    at: walURL,
                    to: backupFile.appendingPathExtension("wal")
                )
            }

            if FileManager.default.fileExists(atPath: shmURL.path) {
                try? FileManager.default.copyItem(
                    at: shmURL,
                    to: backupFile.appendingPathExtension("shm")
                )
            }
        }

        // Сохраняем metadata
        let metadata = BackupMetadata(
            id: backupId,
            date: Date(),
            recordCount: await getRecordCount(),
            schemaVersion: "production_v1"
        )

        let metadataFile = backupPath.appendingPathComponent("\(backupId).json")
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: metadataFile)

        return backupId
    }

    private func rollbackToBackup(_ backupId: String) async throws {
        print("🔄 [Migration] Rolling back to backup \(backupId)...")

        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw MigrationError.rollbackFailed("Cannot access documents directory")
        }

        let backupPath = documentsPath.appendingPathComponent("backups")
        let backupFile = backupPath.appendingPathComponent("\(backupId).sqlite")

        guard FileManager.default.fileExists(atPath: backupFile.path) else {
            throw MigrationError.rollbackFailed("Backup file not found")
        }

        // Закрываем текущий persistent store
        if let store = persistenceController.container.persistentStoreCoordinator.persistentStores.first {
            try persistenceController.container.persistentStoreCoordinator.remove(store)
        }

        // Восстанавливаем из backup
        if let storeURL = persistenceController.container.persistentStoreDescriptions.first?.url {
            // Удаляем текущий store
            try? FileManager.default.removeItem(at: storeURL)

            // Копируем backup
            try FileManager.default.copyItem(at: backupFile, to: storeURL)

            // Восстанавливаем WAL и SHM
            let walBackup = backupFile.appendingPathExtension("wal")
            let shmBackup = backupFile.appendingPathExtension("shm")

            if FileManager.default.fileExists(atPath: walBackup.path) {
                try? FileManager.default.copyItem(
                    at: walBackup,
                    to: storeURL.appendingPathExtension("wal")
                )
            }

            if FileManager.default.fileExists(atPath: shmBackup.path) {
                try? FileManager.default.copyItem(
                    at: shmBackup,
                    to: storeURL.appendingPathExtension("shm")
                )
            }

            // Переоткрываем store
            try persistenceController.container.persistentStoreCoordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: nil
            )
        }

        print("✅ [Migration] Rollback successful")
    }

    // MARK: - Batch Migration

    private func prepareMigrationBatches() async throws -> [MigrationBatch] {
        let context = persistenceController.container.viewContext
        var batches: [MigrationBatch] = []

        await context.perform {
            // Получаем все TaskEntity
            let taskFetch = NSFetchRequest<NSManagedObject>(entityName: "TaskEntity")
            taskFetch.fetchBatchSize = self.batchSize

            if let tasks = try? context.fetch(taskFetch) {
                // Разбиваем на батчи
                let taskBatches = stride(from: 0, to: tasks.count, by: self.batchSize).map { offset in
                    Array(tasks[offset..<min(offset + self.batchSize, tasks.count)])
                }

                for (index, taskBatch) in taskBatches.enumerated() {
                    batches.append(MigrationBatch(
                        id: "tasks_\(index)",
                        entityType: .task,
                        records: taskBatch
                    ))
                }
            }

            // Получаем все EventEntity
            let eventFetch = NSFetchRequest<NSManagedObject>(entityName: "EventEntity")
            eventFetch.fetchBatchSize = self.batchSize

            if let events = try? context.fetch(eventFetch) {
                let eventBatches = stride(from: 0, to: events.count, by: self.batchSize).map { offset in
                    Array(events[offset..<min(offset + self.batchSize, events.count)])
                }

                for (index, eventBatch) in eventBatches.enumerated() {
                    batches.append(MigrationBatch(
                        id: "events_\(index)",
                        entityType: .event,
                        records: eventBatch
                    ))
                }
            }
        }

        return batches
    }

    private func migrateBatch(_ batch: MigrationBatch) async throws {
        let context = persistenceController.container.newBackgroundContext()

        try await context.perform {
            for record in batch.records {
                // Генерируем embedding для записи (заглушка для Week 1-2)
                // TODO: Интегрировать с LocalEmbedder в Week 1-2
                let embedding = self.generatePlaceholderEmbedding()
                record.setValue(embedding, forKey: "embeddingVector")

                // Устанавливаем дефолтные значения для новых полей
                if record.value(forKey: "conflictVersion") == nil {
                    record.setValue(1, forKey: "conflictVersion")
                }

                // aiMetadata - пока пустой
                if record.value(forKey: "aiMetadata") == nil {
                    record.setValue("{}", forKey: "aiMetadata")
                }
            }

            // Сохраняем батч
            if context.hasChanges {
                try context.save()
            }
        }
    }

    private func validateBatch(_ batch: MigrationBatch) async throws {
        let context = persistenceController.container.viewContext

        try await context.perform {
            for record in batch.records {
                // Проверяем что новые поля заполнены
                guard let _ = record.value(forKey: "conflictVersion") as? Int32 else {
                    throw MigrationError.validationFailed("Missing conflictVersion for record")
                }

                guard let _ = record.value(forKey: "aiMetadata") as? String else {
                    throw MigrationError.validationFailed("Missing aiMetadata for record")
                }

                // embeddingVector опционален, но если заполнен - проверяем размер
                if let embedding = record.value(forKey: "embeddingVector") as? Data {
                    // 768 floats * 4 bytes = 3072 bytes
                    guard embedding.count > 0 else {
                        throw MigrationError.validationFailed("Invalid embedding size")
                    }
                }
            }
        }
    }

    // MARK: - Validation

    private func performFullValidation() async throws {
        let context = persistenceController.container.viewContext

        try await context.perform {
            // Проверяем что все записи мигрированы корректно
            let taskFetch = NSFetchRequest<NSManagedObject>(entityName: "TaskEntity")
            let tasks = try context.fetch(taskFetch)

            for task in tasks {
                guard let _ = task.value(forKey: "conflictVersion") as? Int32 else {
                    throw MigrationError.validationFailed("Task missing conflictVersion")
                }
            }

            let eventFetch = NSFetchRequest<NSManagedObject>(entityName: "EventEntity")
            let events = try context.fetch(eventFetch)

            for event in events {
                guard let _ = event.value(forKey: "conflictVersion") as? Int32 else {
                    throw MigrationError.validationFailed("Event missing conflictVersion")
                }
            }
        }
    }

    // MARK: - Helpers

    private func getRecordCount() async -> Int {
        let context = persistenceController.container.viewContext
        var count = 0

        await context.perform {
            let taskCount = (try? context.count(for: NSFetchRequest<NSManagedObject>(entityName: "TaskEntity"))) ?? 0
            let eventCount = (try? context.count(for: NSFetchRequest<NSManagedObject>(entityName: "EventEntity"))) ?? 0
            count = taskCount + eventCount
        }

        return count
    }

    private func cleanupOldBackups(keepRecent: Int) async {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let backupPath = documentsPath.appendingPathComponent("backups")

        guard let backupFiles = try? FileManager.default.contentsOfDirectory(
            at: backupPath,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }

        // Сортируем по дате создания
        let sortedBackups = backupFiles.filter { $0.pathExtension == "sqlite" }.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return date1 > date2
        }

        // Удаляем старые backup'ы
        for backup in sortedBackups.dropFirst(keepRecent) {
            try? FileManager.default.removeItem(at: backup)

            // Удаляем связанные файлы
            let baseURL = backup.deletingPathExtension()
            try? FileManager.default.removeItem(at: baseURL.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: baseURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: baseURL.appendingPathExtension("json"))
        }
    }

    private func generatePlaceholderEmbedding() -> Data {
        // Placeholder: 768-dimensional zero vector
        // TODO: Replace with real LocalEmbedder in Week 1-2
        let zeros = [Float](repeating: 0.0, count: 768)
        return Data(bytes: zeros, count: zeros.count * MemoryLayout<Float>.size)
    }
}

// MARK: - Data Models

struct MigrationBatch {
    let id: String
    let entityType: EntityType
    let records: [NSManagedObject]
}

enum EntityType {
    case task
    case event
    case project
}

struct MigrationProgress {
    let phase: MigrationPhase
    let current: Int
    let total: Int
    let message: String

    var percentage: Double {
        return total > 0 ? Double(current) / Double(total) : 0.0
    }
}

enum MigrationPhase {
    case preparing
    case backup
    case migrating
    case validating
    case completed
    case failed
}

struct BackupMetadata: Codable {
    let id: String
    let date: Date
    let recordCount: Int
    let schemaVersion: String
}

enum MigrationError: Error, LocalizedError {
    case notReady(report: MigrationReport)
    case backupFailed(String)
    case batchFailed(batchIndex: Int, error: Error)
    case validationFailed(String)
    case rollbackFailed(String)

    var errorDescription: String? {
        switch self {
        case .notReady(let report):
            return "Migration not ready: \(report.criticalIssues.count) critical issues"
        case .backupFailed(let reason):
            return "Backup failed: \(reason)"
        case .batchFailed(let index, let error):
            return "Batch \(index) failed: \(error.localizedDescription)"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        case .rollbackFailed(let reason):
            return "Rollback failed: \(reason)"
        }
    }
}
