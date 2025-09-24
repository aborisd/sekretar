import SwiftUI
import EventKit
import CoreData

struct CalendarScreen: View {
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var viewMode: CalendarViewMode = .month
    @State private var events: [EKEvent] = []
    @State private var showingEventDetail = false
    @State private var selectedEvent: EKEvent?
    
    private let calendar = Calendar.current
    
    enum CalendarViewMode: String, CaseIterable {
        case day = "День"
        case week = "Неделя"
        case month = "Месяц"
        
        var systemImage: String {
            switch self {
            case .day: return "calendar.day.timeline.left"
            case .week: return "calendar"
            case .month: return "calendar.month"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // View mode picker
                viewModePickerView
                
                // Calendar content based on selected mode
                Group {
                    switch viewMode {
                    case .day:
                        dayView
                    case .week:
                        weekView
                    case .month:
                        monthView
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Календарь")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadEvents()
            }
            .onReceive(NotificationCenter.default.publisher(for: .focusCalendarDate)) { note in
                if let d = note.userInfo?["date"] as? Date {
                    selectedDate = d
                    loadEventsForDate(d)
                }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event)
            }
        }
    }
    
    private var viewModePickerView: some View {
        Picker("View Mode", selection: $viewMode) {
            ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                HStack {
                    Image(systemName: mode.systemImage)
                    Text(mode.rawValue)
                }
                .tag(mode)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private var dayView: some View {
        VStack(spacing: 0) {
            // Day header
            dayHeaderView
            
            // Day timeline
            dayTimelineView
        }
    }
    
    private var dayHeaderView: some View {
        HStack {
            Button(action: previousDay) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            
            Spacer()
            
            VStack {
                Text(dayTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(daySubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: nextDay) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    private var dayTimelineView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<24) { hour in
                    HStack(alignment: .top) {
                        Text("\(hour):00")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 0.5)
                        
                        Spacer()
                    }
                    .frame(height: 60)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var weekView: some View {
        VStack(spacing: 0) {
            // Week header
            weekHeaderView
            
            // Week grid
            weekGridView
        }
    }
    
    private var weekHeaderView: some View {
        HStack {
            Button(action: previousWeek) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            
            Spacer()
            
            Text(weekTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: nextWeek) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    private var weekGridView: some View {
        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { date in
                    VStack {
                        Text(dayOfWeekFormatter.string(from: date))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(dayFormatter.string(from: date))
                            .font(.title3)
                            .fontWeight(calendar.isDate(date, inSameDayAs: selectedDate) ? .bold : .regular)
                            .foregroundColor(calendar.isDateInToday(date) ? .blue : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        selectedDate = date
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            // Week timeline (simplified)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(stride(from: 6, through: 22, by: 2)), id: \.self) { hour in
                        HStack {
                            Text("\(hour):00")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 40)
                            
                            HStack(spacing: 1) {
                                ForEach(weekDays, id: \.self) { date in
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 40)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private var monthView: some View {
        VStack(spacing: 0) {
            // Month header
            monthHeaderView
            
            // Calendar grid
            calendarGridView
            
            // Events list for selected date
            eventsListView
        }
    }
    
    private var monthHeaderView: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            
            Spacer()
            
            Text(monthTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    private var calendarGridView: some View {
        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 0) {
                ForEach(["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
            
            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 2) {
                ForEach(calendarDays, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        hasEvents: hasEventsForDate(date),
                        isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                    )
                    .onTapGesture {
                        selectedDate = date
                        loadEventsForDate(date)
                    }
                }
            }
            .padding(.horizontal, 5)
        }
    }
    
    private var eventsListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("События на \(selectedDate, formatter: dateFormatter)")
                .font(.headline)
                .padding(.horizontal)
            
            if events.isEmpty {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(.secondary)
                    Text("Нет событий")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(events, id: \.eventIdentifier) { event in
                            EventRowView(event: event)
                                .onTapGesture {
                                    selectedEvent = event
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxHeight: 200)
    }
    
    // MARK: - Computed Properties
    
    private var dayTitle: String {
        dayFormatter.string(from: selectedDate)
    }
    
    private var daySubtitle: String {
        fullDateFormatter.string(from: selectedDate)
    }
    
    private var weekTitle: String {
        let start = startOfWeek(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return "\(dayFormatter.string(from: start)) - \(dayFormatter.string(from: end)) \(monthYearFormatter.string(from: start))"
    }
    
    private var monthTitle: String {
        monthYearFormatter.string(from: currentMonth)
    }
    
    private var weekDays: [Date] {
        let start = startOfWeek(for: selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    
    private var calendarDays: [Date] {
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let startOfCalendar = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
        
        var days: [Date] = []
        for i in 0..<42 { // 6 weeks × 7 days
            if let day = calendar.date(byAdding: .day, value: i, to: startOfCalendar) {
                days.append(day)
            }
        }
        
        return days
    }
    
    // MARK: - Formatters
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    private var dayOfWeekFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }
    
    private var fullDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }
    
    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }
    
    // MARK: - Helper Methods
    
    private func startOfWeek(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    private func hasEventsForDate(_ date: Date) -> Bool {
        // Check calendar events for the date
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Check EventKit events
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            let predicate = EKEventStore().predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
            let ekEvents = EKEventStore().events(matching: predicate)
            if !ekEvents.isEmpty { return true }
        }
        
        // Check Core Data events
        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        request.predicate = NSPredicate(format: "startDate >= %@ AND startDate < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            let coreDataEvents = try PersistenceController.shared.container.viewContext.fetch(request)
            return !coreDataEvents.isEmpty
        } catch {
            return false
        }
    }
    
    // MARK: - Navigation Actions
    
    private func previousDay() {
        if let newDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
            selectedDate = newDate
            loadEventsForDate(selectedDate)
        }
    }
    
    private func nextDay() {
        if let newDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) {
            selectedDate = newDate
            loadEventsForDate(selectedDate)
        }
    }
    
    private func previousWeek() {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) {
            selectedDate = newDate
            loadEventsForDate(selectedDate)
        }
    }
    
    private func nextWeek() {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) {
            selectedDate = newDate
            loadEventsForDate(selectedDate)
        }
    }
    
    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func loadEvents() {
        loadEventsForDate(selectedDate)
    }
    
    private func loadEventsForDate(_ date: Date) {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        var allEvents: [EKEvent] = []
        
        // Load EventKit events
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            let eventStore = EKEventStore()
            let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
            let ekEvents = eventStore.events(matching: predicate)
            allEvents.append(contentsOf: ekEvents)
        }
        
        // Load Core Data events and convert to EKEvent format
        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        request.predicate = NSPredicate(format: "startDate >= %@ AND startDate < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            let coreDataEvents = try PersistenceController.shared.container.viewContext.fetch(request)
            
            // Convert Core Data events to EKEvent objects for display
            for eventEntity in coreDataEvents {
                let ekEvent = EKEvent(eventStore: EKEventStore())
                ekEvent.title = eventEntity.title
                ekEvent.startDate = eventEntity.startDate
                ekEvent.endDate = eventEntity.endDate
                ekEvent.isAllDay = eventEntity.isAllDay
                ekEvent.notes = eventEntity.notes
                allEvents.append(ekEvent)
            }
        } catch {
            print("Failed to fetch Core Data events: \(error)")
        }
        
        // Sort events by start date
        events = allEvents.sorted { ($0.startDate ?? Date()) < ($1.startDate ?? Date()) }
    }
}

struct EventRowView: View {
    let event: EKEvent
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color(event.calendar?.cgColor ?? CGColor(gray: 0.5, alpha: 1)))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Без названия")
                    .font(.body)
                    .fontWeight(.medium)
                
                if let startDate = event.startDate, let endDate = event.endDate {
                    Text("\(startDate, style: .time) - \(endDate, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct EventDetailView: View {
    let event: EKEvent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(event.title ?? "Событие без названия")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let startDate = event.startDate, let endDate = event.endDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Дата и время")
                            .font(.headline)
                        Text("\(startDate, style: .date)")
                        Text("\(startDate, style: .time) - \(endDate, style: .time)")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let notes = event.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Заметки")
                            .font(.headline)
                        Text(notes)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let location = event.location, !location.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Место")
                            .font(.headline)
                        Text(location)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}

extension EKEvent: @retroactive Identifiable {
    public var id: String {
        return eventIdentifier ?? UUID().uuidString
    }
}

#Preview {
    CalendarScreen()
}
