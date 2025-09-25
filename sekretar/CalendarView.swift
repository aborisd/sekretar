import SwiftUI
import EventKit

struct CalendarView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showingDayTasks = false
    @FetchRequest private var tasks: FetchedResults<TaskEntity>
    
    init() {
        _tasks = FetchRequest(
            entity: TaskEntity.entity(),
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Calendar Header
                calendarHeader
                
                // Calendar Grid
                calendarGrid
                
                // Tasks for selected day
                selectedDayTasks
                
                Spacer(minLength: 100) // Space for AI chat
            }
        }
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $showingDayTasks) {
            NavigationView {
                VStack {
                    Text("Задачи на \(selectedDateString)")
                        .font(.title2)
                        .padding()
                    
                    if tasksForSelectedDay.isEmpty {
                        Text("Нет задач на этот день")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        List(tasksForSelectedDay, id: \.id) { task in
                            TaskRowView(task: task)
                        }
                    }
                }
#if os(iOS)
                .navigationBarItems(trailing: Button("Готово") {
                    showingDayTasks = false
                })
#endif
            }
        }
    }
    
    // MARK: - Calendar Header
    private var calendarHeader: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(DesignSystem.Colors.primaryBlue)
            }
            
            Spacer()
            
            Text(monthYearString)
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(DesignSystem.Colors.primaryBlue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, DesignSystem.Spacing.md)
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { weekday in
                    Text(weekday)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                }
            }
            
            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: DesignSystem.Spacing.xs) {
                ForEach(calendarDays, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        isToday: Calendar.current.isDate(date, inSameDayAs: Date()),
                        isCurrentMonth: Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month),
                        taskCount: taskCount(for: date)
                    ) {
                        selectedDate = date
                        showingDayTasks = true
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Selected Day Tasks
    private var selectedDayTasks: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text(selectedDateString)
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("\(tasksForSelectedDay.count) задач")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            if tasksForSelectedDay.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        
                        Text("Нет задач на этот день")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, 40)
                    Spacer()
                }
            } else {
                ForEach(tasksForSelectedDay, id: \.id) { task in
                    TaskRowView(task: task)
                }
            }
        }
        .padding()
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.top, DesignSystem.Spacing.lg)
    }
    
    // MARK: - Computed Properties
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: currentMonth).capitalized
    }
    
    private var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: selectedDate)
    }
    
    private var weekdayHeaders: [String] {
        ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    }
    
    private var calendarDays: [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
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
        let lastDayOfMonth = days.last ?? currentMonth
        
        for i in 1...remainingDays {
            if let date = calendar.date(byAdding: .day, value: i, to: lastDayOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private var tasksForSelectedDay: [TaskEntity] {
        let calendar = Calendar.current
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: selectedDate)
        }
    }
    
    // MARK: - Helper Methods
    private func taskCount(for date: Date) -> Int {
        let calendar = Calendar.current
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }.count
    }
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}


struct TasksView: View {
    var body: some View {
        VStack {
            Text("Tasks")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Swipe navigation working!")
                .foregroundColor(.secondary)
        }
    }
}
