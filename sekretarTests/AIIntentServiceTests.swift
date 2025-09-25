import Testing
import CoreData
@testable import sekretar

struct AIIntentServiceTests {
    private func makeInMemoryContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).container.viewContext
    }

    @Test func testConfirmCreateTaskActionCreatesTask() async throws {
        let context = makeInMemoryContext()
        let service = await MainActor.run { AIIntentService(context: context, llmProvider: OnDeviceLLMStub()) }

        let action = AIAction(
            type: .createTask,
            title: "Create task",
            description: "",
            confidence: 1.0,
            requiresConfirmation: true,
            payload: [
                "title": "Подготовить отчёт",
                "notes": "Собрать метрики за неделю"
            ]
        )

        await MainActor.run { service.pendingAction = action }
        await service.confirmPendingAction()

        let request = NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
        let tasks = try context.fetch(request)

        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Подготовить отчёт")
        let pending = await MainActor.run { service.pendingAction }
        let lastLink = await MainActor.run { service.lastOpenLink }
        #expect(pending == nil)
        #expect(lastLink?.tab == .tasks)
    }

    @Test func testConfirmUpdateTaskActionAppliesChanges() async throws {
        let context = makeInMemoryContext()
        let existing = TaskEntity(context: context)
        existing.id = UUID()
        existing.title = "Черновик"
        existing.priority = 1
        existing.createdAt = Date()
        existing.updatedAt = Date()
        try context.save()

        let service = await MainActor.run { AIIntentService(context: context, llmProvider: OnDeviceLLMStub()) }

        let action = AIAction(
            type: .updateTask,
            title: "Update task",
            description: "",
            confidence: 1.0,
            requiresConfirmation: true,
            payload: [
                "task_id": existing.id?.uuidString ?? "",
                "title": "Обновлённая задача",
                "priority": 3,
                "notes": "Дополнить данными"
            ]
        )

        await MainActor.run { service.pendingAction = action }
        await service.confirmPendingAction()

        let request = NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
        request.predicate = NSPredicate(format: "id == %@", existing.id! as CVarArg)
        let updated = try context.fetch(request).first

        #expect(updated?.title == "Обновлённая задача")
        #expect(updated?.notes == "Дополнить данными")
        #expect(updated?.priority == 3)
        let pending = await MainActor.run { service.pendingAction }
        #expect(pending == nil)
    }
}
