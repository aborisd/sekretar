import Foundation
import CoreData

@MainActor
enum MaintenanceService {
    static func purgeEmptyDraftTasks(in context: NSManagedObjectContext) async {
        await context.perform {
            let fr: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            fr.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "title == nil"),
                NSPredicate(format: "title == ''")
            ])
            fr.fetchBatchSize = 200
            fr.fetchLimit = 5000
            if let drafts = try? context.fetch(fr), !drafts.isEmpty {
                drafts.forEach { context.delete($0) }
                try? context.save()
            }
        }
    }
}

