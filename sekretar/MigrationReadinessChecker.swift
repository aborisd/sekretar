import Foundation
import CoreData

// MARK: - Migration Readiness Assessment (из ai_calendar_production_plan_v4.md, Section 3)

/// Проверяет готовность системы к миграции на production schema
class MigrationReadinessChecker {

    private let persistenceController: PersistenceController

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - Main Assessment

    /// Полная оценка готовности к миграции
    func assessReadiness() async throws -> MigrationReport {
        var issues: [MigrationIssue] = []

        print("🔍 [Migration] Starting readiness assessment...")

        // 1. Проверка целостности данных
        print("  - Checking data integrity...")
        let dataIntegrity = await checkDataIntegrity()
        if dataIntegrity.corruptedRecords > 0 {
            issues.append(.dataCorruption(count: dataIntegrity.corruptedRecords))
        }
        print("    ✓ Found \(dataIntegrity.totalRecords) records, \(dataIntegrity.corruptedRecords) corrupted")

        // 2. Проверка совместимости схемы
        print("  - Checking schema compatibility...")
        let schemaCompatibility = await checkSchemaCompatibility()
        if !schemaCompatibility.isCompatible {
            issues.append(.schemaIncompatible(fields: schemaCompatibility.incompatibleFields))
        }
        print("    ✓ Schema compatibility: \(schemaCompatibility.isCompatible ? "OK" : "ISSUES FOUND")")

        // 3. Оценка объема данных для миграции
        print("  - Estimating migration volume...")
        let dataVolume = await estimateDataVolume()
        if dataVolume.estimatedTime > 3600 { // >1 час
            issues.append(.longMigrationTime(estimated: dataVolume.estimatedTime))
        }
        print("    ✓ Estimated migration time: \(Int(dataVolume.estimatedTime))s")

        // 4. Проверка зависимостей
        print("  - Checking dependencies...")
        let deps = await checkDependencies()
        if !deps.allSatisfied {
            issues.append(.missingDependencies(deps.missing))
        }
        print("    ✓ Dependencies: \(deps.allSatisfied ? "OK" : "MISSING: \(deps.missing.joined(separator: ", "))")")

        let canProceed = issues.filter { $0.isCritical }.isEmpty

        print("\n📊 [Migration] Assessment complete: \(canProceed ? "✅ READY" : "❌ NOT READY")")

        return MigrationReport(
            canProceed: canProceed,
            criticalIssues: issues.filter { $0.isCritical },
            warnings: issues.filter { !$0.isCritical },
            recommendations: generateRecommendations(issues: issues),
            assessmentDate: Date()
        )
    }

    // MARK: - Data Integrity Check

    private func checkDataIntegrity() async -> DataIntegrityResult {
        let context = persistenceController.container.viewContext
        var totalRecords = 0
        var corruptedRecords = 0

        await context.perform {
            // Проверяем TaskEntity
            let taskFetch = NSFetchRequest<NSManagedObject>(entityName: "TaskEntity")
            taskFetch.includesPropertyValues = false

            do {
                let tasks = try context.fetch(taskFetch)
                totalRecords += tasks.count

                // Проверяем каждую задачу на корректность
                for task in tasks {
                    if !self.validateTaskIntegrity(task, context: context) {
                        corruptedRecords += 1
                    }
                }
            } catch {
                print("❌ Error fetching tasks: \(error)")
            }

            // Проверяем EventEntity
            let eventFetch = NSFetchRequest<NSManagedObject>(entityName: "EventEntity")
            eventFetch.includesPropertyValues = false

            do {
                let events = try context.fetch(eventFetch)
                totalRecords += events.count

                for event in events {
                    if !self.validateEventIntegrity(event, context: context) {
                        corruptedRecords += 1
                    }
                }
            } catch {
                print("❌ Error fetching events: \(error)")
            }
        }

        return DataIntegrityResult(
            totalRecords: totalRecords,
            corruptedRecords: corruptedRecords,
            validRecords: totalRecords - corruptedRecords
        )
    }

    private func validateTaskIntegrity(_ task: NSManagedObject, context: NSManagedObjectContext) -> Bool {
        // Проверяем обязательные поля
        guard let _ = task.value(forKey: "id") as? UUID,
              let title = task.value(forKey: "title") as? String,
              !title.isEmpty,
              let _ = task.value(forKey: "createdAt") as? Date,
              let _ = task.value(forKey: "updatedAt") as? Date else {
            return false
        }

        // Проверяем логичность дат
        if let dueDate = task.value(forKey: "dueDate") as? Date,
           let createdAt = task.value(forKey: "createdAt") as? Date,
           dueDate < createdAt.addingTimeInterval(-86400) { // Due date более чем за день до создания - странно
            return false
        }

        return true
    }

    private func validateEventIntegrity(_ event: NSManagedObject, context: NSManagedObjectContext) -> Bool {
        // Проверяем обязательные поля
        guard let _ = event.value(forKey: "id") as? UUID,
              let title = event.value(forKey: "title") as? String,
              !title.isEmpty,
              let startDate = event.value(forKey: "startDate") as? Date,
              let endDate = event.value(forKey: "endDate") as? Date else {
            return false
        }

        // Проверяем что endDate > startDate
        if endDate <= startDate {
            return false
        }

        return true
    }

    // MARK: - Schema Compatibility Check

    private func checkSchemaCompatibility() async -> SchemaCompatibilityResult {
        var incompatibleFields: [String] = []

        let context = persistenceController.container.viewContext

        await context.perform {
            let model = self.persistenceController.container.managedObjectModel

            // Проверяем TaskEntity
            if let taskEntity = model.entitiesByName["TaskEntity"] {
                let requiredFields = ["id", "title", "createdAt", "updatedAt"]
                let existingFields = taskEntity.propertiesByName.keys.map { String($0) }

                for field in requiredFields {
                    if !existingFields.contains(field) {
                        incompatibleFields.append("TaskEntity.\(field)")
                    }
                }

                // Проверяем новые production поля (должны быть опциональными)
                let productionFields = ["embeddingVector", "aiMetadata", "serverSyncId", "lastSyncedAt", "conflictVersion"]
                for field in productionFields {
                    if let property = taskEntity.propertiesByName[field] as? NSAttributeDescription {
                        // Новые поля должны быть опциональными для безопасной миграции
                        if !property.isOptional && field != "conflictVersion" {
                            incompatibleFields.append("TaskEntity.\(field) (should be optional)")
                        }
                    }
                }
            }

            // Проверяем EventEntity
            if let eventEntity = model.entitiesByName["EventEntity"] {
                let requiredFields = ["id", "title", "startDate", "endDate"]
                let existingFields = eventEntity.propertiesByName.keys.map { String($0) }

                for field in requiredFields {
                    if !existingFields.contains(field) {
                        incompatibleFields.append("EventEntity.\(field)")
                    }
                }
            }
        }

        return SchemaCompatibilityResult(
            isCompatible: incompatibleFields.isEmpty,
            incompatibleFields: incompatibleFields
        )
    }

    // MARK: - Data Volume Estimation

    private func estimateDataVolume() async -> DataVolumeEstimate {
        let context = persistenceController.container.viewContext
        var totalRecords = 0

        await context.perform {
            // Считаем все записи
            let taskCount = (try? context.count(for: NSFetchRequest<NSManagedObject>(entityName: "TaskEntity"))) ?? 0
            let eventCount = (try? context.count(for: NSFetchRequest<NSManagedObject>(entityName: "EventEntity"))) ?? 0
            let projectCount = (try? context.count(for: NSFetchRequest<NSManagedObject>(entityName: "ProjectEntity"))) ?? 0

            totalRecords = taskCount + eventCount + projectCount
        }

        // Оцениваем время: примерно 10 записей в секунду для генерации embeddings
        let estimatedTime = Double(totalRecords) / 10.0

        // Оцениваем размер: каждый embedding ~3KB (768 floats * 4 bytes)
        let estimatedSizeBytes = totalRecords * 3000

        return DataVolumeEstimate(
            totalRecords: totalRecords,
            estimatedTime: estimatedTime,
            estimatedSizeBytes: estimatedSizeBytes
        )
    }

    // MARK: - Dependencies Check

    private func checkDependencies() async -> DependenciesCheckResult {
        var missing: [String] = []

        // Проверяем наличие Core Data stack
        if persistenceController.container.persistentStoreDescriptions.isEmpty {
            missing.append("Core Data persistent store")
        }

        // Проверяем доступность FileManager для кэша
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        if cacheDirectory == nil {
            missing.append("Cache directory")
        }

        // Проверяем доступность Document directory для vector DB
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if documentDirectory == nil {
            missing.append("Document directory")
        }

        // Проверяем доступное дисковое пространство
        if let documentPath = documentDirectory?.path,
           let attributes = try? FileManager.default.attributesOfFileSystem(forPath: documentPath),
           let freeSize = attributes[.systemFreeSize] as? NSNumber {
            let freeMB = freeSize.int64Value / 1024 / 1024
            if freeMB < 100 { // Меньше 100MB свободного места
                missing.append("Insufficient disk space (\(freeMB)MB free)")
            }
        }

        return DependenciesCheckResult(
            allSatisfied: missing.isEmpty,
            missing: missing
        )
    }

    // MARK: - Recommendations Generator

    private func generateRecommendations(issues: [MigrationIssue]) -> [String] {
        var recommendations: [String] = []

        for issue in issues {
            switch issue {
            case .dataCorruption(let count):
                recommendations.append("🔧 Исправить \(count) поврежденных записей перед миграцией")
                recommendations.append("   Используйте DataRepairService для автоматического восстановления")

            case .schemaIncompatible(let fields):
                recommendations.append("📋 Несовместимые поля схемы: \(fields.joined(separator: ", "))")
                recommendations.append("   Обновите Core Data model перед миграцией")

            case .longMigrationTime(let seconds):
                recommendations.append("⏱️ Миграция займет ~\(Int(seconds/60)) минут")
                recommendations.append("   Рекомендуется выполнять в фоне с progress indicator")

            case .missingDependencies(let deps):
                recommendations.append("⚠️ Отсутствуют зависимости: \(deps.joined(separator: ", "))")
                recommendations.append("   Установите необходимые компоненты")
            }
        }

        if recommendations.isEmpty {
            recommendations.append("✅ Система готова к миграции")
            recommendations.append("   Рекомендуется создать backup перед началом")
        }

        return recommendations
    }
}

// MARK: - Data Models

struct MigrationReport {
    let canProceed: Bool
    let criticalIssues: [MigrationIssue]
    let warnings: [MigrationIssue]
    let recommendations: [String]
    let assessmentDate: Date

    var summary: String {
        var text = """
        📊 Migration Readiness Report
        Date: \(assessmentDate.formatted())
        Status: \(canProceed ? "✅ READY TO PROCEED" : "❌ NOT READY")

        """

        if !criticalIssues.isEmpty {
            text += "\n🔴 Critical Issues (\(criticalIssues.count)):\n"
            for (index, issue) in criticalIssues.enumerated() {
                text += "  \(index + 1). \(issue.description)\n"
            }
        }

        if !warnings.isEmpty {
            text += "\n🟡 Warnings (\(warnings.count)):\n"
            for (index, warning) in warnings.enumerated() {
                text += "  \(index + 1). \(warning.description)\n"
            }
        }

        text += "\n💡 Recommendations:\n"
        for (index, rec) in recommendations.enumerated() {
            text += "  \(index + 1). \(rec)\n"
        }

        return text
    }
}

enum MigrationIssue {
    case dataCorruption(count: Int)
    case schemaIncompatible(fields: [String])
    case longMigrationTime(estimated: TimeInterval)
    case missingDependencies([String])

    var isCritical: Bool {
        switch self {
        case .dataCorruption(let count):
            return count > 10 // Больше 10 поврежденных записей - критично
        case .schemaIncompatible:
            return true // Всегда критично
        case .longMigrationTime:
            return false // Warning, но не критично
        case .missingDependencies:
            return true // Критично
        }
    }

    var description: String {
        switch self {
        case .dataCorruption(let count):
            return "Data corruption: \(count) corrupted records found"
        case .schemaIncompatible(let fields):
            return "Schema incompatible: \(fields.joined(separator: ", "))"
        case .longMigrationTime(let seconds):
            return "Long migration time: ~\(Int(seconds))s estimated"
        case .missingDependencies(let deps):
            return "Missing dependencies: \(deps.joined(separator: ", "))"
        }
    }
}

struct DataIntegrityResult {
    let totalRecords: Int
    let corruptedRecords: Int
    let validRecords: Int
}

struct SchemaCompatibilityResult {
    let isCompatible: Bool
    let incompatibleFields: [String]
}

struct DataVolumeEstimate {
    let totalRecords: Int
    let estimatedTime: TimeInterval
    let estimatedSizeBytes: Int
}

struct DependenciesCheckResult {
    let allSatisfied: Bool
    let missing: [String]
}
