import Foundation
import SwiftUI
import Combine
import CoreData

enum CalendarViewMode {
    case day, week, month
}

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var currentDate = Date()
    @Published var viewMode: CalendarViewMode = .month
    @Published var events: [EventEntity] = []
    @Published var tasks: [TaskEntity] = []
    
    private let context: NSManagedObjectContext
    private let eventKitService: EventKitService
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.eventKitService = EventKitService(context: context)
        setupSubscriptions()
        loadDataForCurrentPeriod()
        importEventsForCurrentMonth()
    }
    
    // MARK: - Public Methods
    
    func selectDate(_ date: Date) {
        selectedDate = date
        currentDate = date
        loadDataForCurrentPeriod()
    }
    
    func switchViewMode(_ mode: CalendarViewMode) {
        viewMode = mode
        if mode != .month {
            selectedDate = currentDate
        }
        loadDataForCurrentPeriod()
    }
    
    func navigatePrevious() {
        let calendar = Calendar.current
        switch viewMode {
        case .day:
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        case .week:
            currentDate = calendar.date(byAdding: .weekOfYear, value: -1, to: currentDate) ?? currentDate
        case .month:
            currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
        }
        selectedDate = currentDate
        loadDataForCurrentPeriod()
    }
    
    func navigateNext() {
        let calendar = Calendar.current
        switch viewMode {
        case .day:
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        case .week:
            currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        case .month:
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }
        selectedDate = currentDate
        loadDataForCurrentPeriod()
    }
    
    func goToToday() {
        currentDate = Date()
        selectedDate = Date()
        loadDataForCurrentPeriod()
    }
    
    // MARK: - Computed Properties
    
    var periodString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        
        switch viewMode {
        case .day:
            formatter.dateFormat = "EEEE, d MMMM yyyy"
            return formatter.string(from: currentDate)
        case .week:
            let calendar = Calendar.current
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? currentDate
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? currentDate
            
            formatter.dateFormat = "d MMMM"
            let startString = formatter.string(from: weekStart)
            let endString = formatter.string(from: weekEnd)
            return "\(startString) - \(endString)"
        case .month:
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: currentDate).capitalized
        }
    }
    
    var calendarDays: [Date] {
        let calendar = Calendar.current
        
        switch viewMode {
        case .day:
            return [currentDate]
        case .week:
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentDate)
            guard let start = weekInterval?.start else { return [currentDate] }
            
            var days: [Date] = []
            for i in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: i, to: start) {
                    days.append(date)
                }
            }
            return days
        case .month:
            return generateMonthDays()
        }
    }
    
    // MARK: - Helper Methods
    
    func tasksFor(date: Date) -> [TaskEntity] {
        let calendar = Calendar.current
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
    }
    
    func eventsFor(date: Date) -> [EventEntity] {
        let calendar = Calendar.current
        return events.filter { event in
            guard let startDate = event.startDate else { return false }
            return calendar.isDate(startDate, inSameDayAs: date)
        }
    }
    
    func hasItemsFor(date: Date) -> Bool {
        !tasksFor(date: date).isEmpty || !eventsFor(date: date).isEmpty
    }
    
    func taskCountFor(date: Date) -> Int {
        tasksFor(date: date).count
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: context)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.loadDataForCurrentPeriod()
            }
            .store(in: &cancellables)
    }
    
    private func loadDataForCurrentPeriod() {
        let (startDate, endDate) = getPeriodDateRange()
        
        Task {
            await loadTasks(from: startDate, to: endDate)
            await loadEvents(from: startDate, to: endDate)
        }
    }
    
    private func getPeriodDateRange() -> (Date, Date) {
        let calendar = Calendar.current
        
        switch viewMode {
        case .day:
            let start = calendar.startOfDay(for: currentDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return (start, end)
        case .week:
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentDate)
            let start = weekInterval?.start ?? currentDate
            let end = weekInterval?.end ?? calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return (start, end)
        case .month:
            let monthInterval = calendar.dateInterval(of: .month, for: currentDate)
            let start = monthInterval?.start ?? currentDate
            let end = monthInterval?.end ?? calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return (start, end)
        }
    }
    
    private func loadTasks(from startDate: Date, to endDate: Date) async {
        let fetchedTasks = await context.perform {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "dueDate >= %@ AND dueDate < %@",
                startDate as NSDate,
                endDate as NSDate
            )
            request.sortDescriptors = [
                NSSortDescriptor(key: "dueDate", ascending: true),
                NSSortDescriptor(key: "priority", ascending: false)
            ]
            
            do {
                return try self.context.fetch(request)
            } catch {
                print("Error loading tasks: \(error)")
                return []
            }
        }
        
        await MainActor.run {
            self.tasks = fetchedTasks
        }
    }
    
    private func loadEvents(from startDate: Date, to endDate: Date) async {
        let fetchedEvents = await context.perform {
            let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "startDate >= %@ AND startDate < %@",
                startDate as NSDate,
                endDate as NSDate
            )
            request.sortDescriptors = [
                NSSortDescriptor(key: "startDate", ascending: true)
            ]
            
            do {
                return try self.context.fetch(request)
            } catch {
                print("Error loading events: \(error)")
                return []
            }
        }
        
        await MainActor.run {
            self.events = fetchedEvents
        }
    }
    
    private func generateMonthDays() -> [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
        let range = calendar.range(of: .day, in: .month, for: currentDate)!
        let daysInMonth = range.count
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let adjustedFirstWeekday = (firstWeekday == 1) ? 7 : firstWeekday - 1 // Monday = 1
        
        var days: [Date] = []
        
        // Previous month's trailing days
        for i in 1..<adjustedFirstWeekday {
            if let date = calendar.date(byAdding: .day, value: -adjustedFirstWeekday + i, to: startOfMonth) {
                days.append(date)
            }
        }
        
        // Current month's days
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        // Next month's leading days to fill the grid
        let totalCells = 42 // 6 weeks × 7 days
        let remainingDays = totalCells - days.count
        let lastDayOfMonth = days.last ?? currentDate
        
        for i in 1...remainingDays {
            if let date = calendar.date(byAdding: .day, value: i, to: lastDayOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    // MARK: - EventKit Integration
    
    private func importEventsForCurrentMonth() {
        Task {
            do {
                let calendar = Calendar.current
                let monthInterval = calendar.dateInterval(of: .month, for: currentDate)
                let startDate = monthInterval?.start ?? calendar.startOfDay(for: currentDate)
                let endDate = monthInterval?.end ?? calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
                
                try await eventKitService.importEvents(from: startDate, to: endDate)
                await loadDataForCurrentPeriod() // Refresh the data
            } catch {
                print("Failed to import events: \(error)")
            }
        }
    }
    
    func refreshEventKitImport() {
        importEventsForCurrentMonth()
    }
}
