import Testing
@testable import calendAI
import CoreData

struct calendAITests {
    
    @Test func testTaskRepositoryCreate() async throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let repo = TaskRepositoryCD(context: context)
        
        let task = try await repo.create(title: "Test Task", notes: "Test notes", dueDate: nil, priority: 1)
        
        #expect(task.title == "Test Task")
        #expect(task.notes == "Test notes")
        #expect(task.priority == 1)
        #expect(task.isCompleted == false)
    }
    
    @Test func testTaskRepositoryToggle() async throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let repo = TaskRepositoryCD(context: context)
        
        let task = try await repo.create(title: "Test Task", notes: nil, dueDate: nil, priority: 1)
        let initialState = task.isCompleted
        
        try await repo.toggleComplete(task)
        
        #expect(task.isCompleted == !initialState)
    }
    
    @Test func testAIIntentServiceParsing() async throws {
        let llm = OnDeviceLLMStub()
        let service = AIIntentService(llm: llm)
        
        let intent = try await service.parseIntent(from: "создать задачу")
        
        #expect(intent.action == "create_task")
        #expect(intent.meta.confidence > 0.5)
    }
}
