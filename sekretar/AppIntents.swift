import Foundation
import CoreData
#if canImport(AppIntents)
import AppIntents

// MARK: - "Добавь задачу" (Add Task)
@available(iOS 16.0, macOS 13.0, *)
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Добавить задачу"
    static var description = IntentDescription("Создать новую задачу в списке")

    @Parameter(title: "Название")
    var titleText: String

    func perform() async throws -> some IntentResult {
        let ctx = PersistenceController.shared.container.viewContext
        try await ctx.perform {
            let t = TaskEntity(context: ctx)
            t.id = UUID(); t.title = titleText
            t.priority = 1; t.isCompleted = false
            let now = Date(); t.createdAt = now; t.updatedAt = now
            try ctx.save()
        }
        return .result(value: "Задача добавлена: \(titleText)")
    }
}

// MARK: - "Что сегодня?" (Summary)
@available(iOS 16.0, macOS 13.0, *)
struct TodaySummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Что сегодня?"
    static var description = IntentDescription("Короткое резюме задач на сегодня")

    func perform() async throws -> some IntentResult {
        let ctx = PersistenceController.shared.container.viewContext
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == NO AND dueDate >= %@ AND dueDate < %@", start as NSDate, end as NSDate)
        request.fetchLimit = 50
        let tasks = try await ctx.perform { try ctx.fetch(request) }
        let summary = tasks.prefix(5).compactMap { $0.title }.joined(separator: ", ")
        let text = tasks.isEmpty ? "На сегодня задач нет" : "Сегодня: \(summary)"
        return .result(value: text)
    }
}

// MARK: - App Shortcuts Catalog
@available(iOS 16.0, macOS 13.0, *)
struct SekretarShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddTaskIntent(), phrases: ["Добавь задачу в ${applicationName}"], shortTitle: "Добавить задачу", systemImageName: "checklist")
        AppShortcut(intent: TodaySummaryIntent(), phrases: ["Что сегодня в ${applicationName}"], shortTitle: "Что сегодня?", systemImageName: "calendar")
    }
}
#endif
