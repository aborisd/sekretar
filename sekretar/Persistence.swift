import Foundation
import CoreData

final class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "Sekretar", managedObjectModel: model)
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unresolved error: \(error)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    static func preview() -> PersistenceController {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        
        // Create sample projects
        let workProject = ProjectEntity(context: ctx)
        workProject.id = UUID()
        workProject.title = "Работа"
        workProject.color = "#3B82F6"
        workProject.createdAt = Date()
        
        let personalProject = ProjectEntity(context: ctx)
        personalProject.id = UUID()
        personalProject.title = "Личное"
        personalProject.color = "#10B981"
        personalProject.createdAt = Date()
        
        let studyProject = ProjectEntity(context: ctx)
        studyProject.id = UUID()
        studyProject.title = "Обучение"
        studyProject.color = "#F59E0B"
        studyProject.createdAt = Date()
        
        // Create sample tasks
        let taskTitles = [
            "Подготовить презентацию",
            "Написать отчет",
            "Позвонить клиенту",
            "Купить продукты",
            "Записаться к врачу", 
            "Изучить SwiftUI",
            "Сделать зарядку",
            "Прочитать книгу",
            "Оплатить счета",
            "Встретиться с командой"
        ]
        
        let taskNotes = [
            "Презентация на 15 минут о результатах квартала",
            "Ежемесячный отчет по продажам",
            nil,
            "Молоко, хлеб, овощи для салата",
            "Плановый осмотр у терапевта",
            "Изучить Navigation и State Management",
            "Утренняя зарядка 30 минут",
            "Дочитать 'Thinking, Fast and Slow'",
            "Коммунальные услуги до 10 числа",
            "Обсудить планы на следующий спринт"
        ]
        
        let projects = [workProject, workProject, workProject, personalProject, personalProject, studyProject, personalProject, studyProject, personalProject, workProject]
        
        for i in 0..<taskTitles.count {
            let task = TaskEntity(context: ctx)
            task.id = UUID()
            task.title = taskTitles[i]
            task.notes = taskNotes[i]
            task.priority = Int16([0, 1, 2, 3].randomElement() ?? 1)
            task.isCompleted = [true, false, false, false, false].randomElement() ?? false
            task.createdAt = Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...30), to: Date()) ?? Date()
            task.updatedAt = task.createdAt
            task.project = projects[i]
            
            // Assign due dates
            if i < 7 {
                task.dueDate = Calendar.current.date(byAdding: .day, value: i-3, to: Date())
            }
        }
        
        // Create sample events
        let eventTitles = [
            "Планерка команды",
            "Встреча с клиентом",
            "Обед с коллегами", 
            "Врач",
            "Спортзал",
            "Конференция iOS Dev",
            "День рождения мамы"
        ]
        
        let today = Date()
        let calendar = Calendar.current
        
        for i in 0..<eventTitles.count {
            let event = EventEntity(context: ctx)
            event.id = UUID()
            event.title = eventTitles[i]
            
            let dayOffset = i - 3
            let startDate = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            let startWithTime = calendar.date(byAdding: .hour, value: 9 + (i % 8), to: calendar.startOfDay(for: startDate)) ?? startDate
            
            event.startDate = startWithTime
            event.endDate = calendar.date(byAdding: .hour, value: [1, 2, 3].randomElement() ?? 1, to: startWithTime) ?? startWithTime
            event.isAllDay = (i == eventTitles.count - 1) // Last event is all-day
            
            if i % 3 == 0 {
                event.notes = "Важная встреча"
            }
        }
        
        // Create sample user preferences
        let preferences = [
            ("theme", "light"),
            ("notifications_enabled", "true"),
            ("deep_work_start", "09:00"),
            ("deep_work_end", "11:00"),
            ("quiet_hours_start", "22:00"),
            ("quiet_hours_end", "08:00")
        ]
        
        for (key, value) in preferences {
            let pref = UserPrefEntity(context: ctx)
            pref.id = UUID()
            pref.key = key
            pref.value = value
            pref.updatedAt = Date()
        }
        
        // Create sample AI action log
        let aiAction = AIActionLogEntity(context: ctx)
        aiAction.id = UUID()
        aiAction.action = "createTask"
        aiAction.payload = #"{"title": "Тестовая задача", "priority": 2}"#
        aiAction.createdAt = Date()
        aiAction.confidence = 0.95
        aiAction.requiresConfirmation = false
        aiAction.isExecuted = false
        
        try? ctx.save()
        return controller
    }
}
