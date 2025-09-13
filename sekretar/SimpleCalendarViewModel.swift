import SwiftUI
import EventKit
import CoreData

@MainActor
final class SimpleCalendarViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var currentMonth = Date()
    @Published var events: [EventEntity] = []
    @Published var tasks: [TaskEntity] = []
    
    private let context: NSManagedObjectContext
    private let eventKitService: EventKitService
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.eventKitService = EventKitService(context: context)
        loadData()
    }
    
    func loadData() {
        loadTasks()
        loadEvents()
    }
    
    private func loadTasks() {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        
        do {
            tasks = try context.fetch(request)
        } catch {
            print("Failed to load tasks: \(error)")
            tasks = []
        }
    }
    
    private func loadEvents() {
        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        
        do {
            events = try context.fetch(request)
        } catch {
            print("Failed to load events: \(error)")
            events = []
        }
    }
    
    func selectDate(_ date: Date) {
        selectedDate = date
    }
    
    func changeMonth(by value: Int) {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}