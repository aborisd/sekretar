import SwiftUI
import CoreData

struct CalendarScreen: View {
    @StateObject private var viewModel: CalendarViewModel
    @State private var presentedDetail: CalendarDetail?

    private struct ModeOption: Identifiable {
        let id: CalendarViewMode
        let title: String
        let icon: String
    }

    fileprivate enum CalendarDetail: Identifiable {
        case event(EventEntity)
        case task(TaskEntity)

        var id: NSManagedObjectID {
            switch self {
            case .event(let event):
                return event.objectID
            case .task(let task):
                return task.objectID
            }
        }
    }

    private let modeOptions: [ModeOption] = [
        .init(id: .day, title: "День", icon: "calendar.day.timeline.left"),
        .init(id: .week, title: "Неделя", icon: "calendar"),
        .init(id: .month, title: "Месяц", icon: "calendar.month")
    ]

    private let calendar = Calendar.current

    init(viewModel: CalendarViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    modePicker
                    Group {
                        switch viewModel.viewMode {
                        case .day:
                            dayView
                        case .week:
                            weekView
                        case .month:
                            monthView
                        }
                    }
                    agendaSection
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Календарь")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сегодня") { viewModel.goToToday() }
                        .font(.callout)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .focusCalendarDate)) { note in
                if let date = note.userInfo?["date"] as? Date {
                    viewModel.selectDate(date)
                }
            }
            .sheet(item: $presentedDetail) { detail in
                CalendarDetailSheet(detail: detail)
            }
        }
    }
}

// MARK: - Subviews
private extension CalendarScreen {
    var modePicker: some View {
        Picker("", selection: viewModeBinding) {
            ForEach(modeOptions) { option in
                Label(option.title, systemImage: option.icon)
                    .tag(option.id)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    var dayView: some View {
        VStack(spacing: 16) {
            header(title: longDateFormatter.string(from: viewModel.selectedDate), subtitle: weekdayFormatter.string(from: viewModel.selectedDate))
            dayTimeline
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    var weekView: some View {
        VStack(spacing: 16) {
            header(title: weekTitle, subtitle: monthYearFormatter.string(from: viewModel.currentDate))
            weekGrid
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    var monthView: some View {
        VStack(spacing: 12) {
            header(title: monthYearFormatter.string(from: viewModel.currentDate).capitalized, subtitle: "")
            weekdayHeader
            monthGrid
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    var agendaSection: some View {
        let events = viewModel.eventsFor(date: viewModel.selectedDate)
        let tasks = viewModel.tasksFor(date: viewModel.selectedDate)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Запланировано на \(shortDateFormatter.string(from: viewModel.selectedDate))")
                    .font(.headline)
                Spacer()
                if !calendar.isDateInToday(viewModel.selectedDate) {
                    Button("Сегодня") { viewModel.goToToday() }
                        .font(.subheadline)
                }
            }

            if events.isEmpty && tasks.isEmpty {
                emptyAgendaPlaceholder
            } else {
                if !events.isEmpty {
                    Text("События")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ForEach(events, id: \.objectID) { event in
                        agendaRow.eventRow(event: event)
                            .onTapGesture { presentedDetail = .event(event) }
                    }
                }

                if !tasks.isEmpty {
                    Text("Задачи")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, events.isEmpty ? 0 : 8)
                    ForEach(tasks, id: \.objectID) { task in
                        agendaRow.taskRow(task: task)
                            .onTapGesture { presentedDetail = .task(task) }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    var emptyAgendaPlaceholder: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Нет запланированных событий или задач")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func header(title: String, subtitle: String) -> some View {
        HStack {
            Button(action: viewModel.navigatePrevious) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            Spacer()

            VStack(spacing: subtitle.isEmpty ? 0 : 2) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: viewModel.navigateNext) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
    }

    var dayTimeline: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<24) { hour in
                    HStack(alignment: .top) {
                        Text(String(format: "%02d:00", hour))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 44, alignment: .trailing)
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 0.5)
                        Spacer()
                    }
                    .frame(height: 48)
                }
            }
        }
        .frame(maxHeight: 320)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray.opacity(0.15))
        )
    }

    var weekGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { date in
                    VStack(spacing: 6) {
                        Text(weekdayShortFormatter.string(from: date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(dayNumberFormatter.string(from: date))
                            .font(.title3)
                            .fontWeight(calendar.isDate(date, inSameDayAs: viewModel.selectedDate) ? .bold : .regular)
                            .foregroundColor(calendar.isDateInToday(date) ? .blue : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(calendar.isDate(date, inSameDayAs: viewModel.selectedDate) ? Color.blue.opacity(0.12) : .clear)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.selectDate(date) }
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 12) {
                ForEach(weekDays, id: \.self) { date in
                    VStack(spacing: 8) {
                        if calendar.isDate(date, inSameDayAs: viewModel.selectedDate) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                        } else {
                            Color.clear.frame(width: 6, height: 6)
                        }

                        let indicatorColors = priorityIndicators(for: date)
                        if indicatorColors.isEmpty {
                            Spacer().frame(height: 8)
                        } else {
                            HStack(spacing: 4) {
                                ForEach(Array(indicatorColors.enumerated()), id: \.offset) { item in
                                    Circle()
                                        .fill(item.element)
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(viewModel.calendarDays, id: \.self) { date in
                CalendarDayView(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: viewModel.selectedDate),
                    isToday: calendar.isDateInToday(date),
                    hasEvents: viewModel.hasItemsFor(date: date),
                    isCurrentMonth: calendar.isDate(date, equalTo: viewModel.currentDate, toGranularity: .month)
                )
                .onTapGesture { viewModel.selectDate(date) }
            }
        }
        .padding(.top, 4)
    }

    var weekDays: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: viewModel.currentDate)?.start ?? viewModel.currentDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var weekTitle: String {
        let start = weekDays.first ?? viewModel.currentDate
        let end = weekDays.last ?? start
        return "\(shortDateFormatter.string(from: start)) – \(shortDateFormatter.string(from: end))"
    }

    var agendaRow: AgendaRowBuilder { AgendaRowBuilder(timeFormatter: timeFormatter) }

    private func priorityIndicators(for date: Date) -> [Color] {
        let tasks = viewModel.tasksFor(date: date)
            .sorted { ($0.priority) > ($1.priority) }

        if !tasks.isEmpty {
            return tasks.prefix(3).map { priorityColor(for: $0.priority) }
        }

        let hasEvents = !viewModel.eventsFor(date: date).isEmpty
        return hasEvents ? [Color.blue] : []
    }

    private func priorityColor(for priority: Int16) -> Color {
        switch priority {
        case 3: return DesignSystem.Colors.priorityHigh
        case 2: return DesignSystem.Colors.priorityMedium
        case 1: return DesignSystem.Colors.priorityLow
        default: return DesignSystem.Colors.priorityNone
        }
    }
}

// MARK: - Agenda row builder
private struct AgendaRowBuilder {
    let timeFormatter: DateFormatter

    func eventRow(event: EventEntity) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if let start = event.startDate {
                let end = event.endDate ?? start.addingTimeInterval(3600)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeFormatter.string(from: start))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(timeFormatter.string(from: end))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 64, alignment: .trailing)
            } else {
                Color.clear.frame(width: 64, height: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text(event.title ?? "Событие")
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }

                if event.isAllDay && event.startDate != nil {
                    Text("Весь день")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }

    func taskRow(task: TaskEntity) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if let due = task.dueDate {
                Text(timeFormatter.string(from: due))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(width: 64, alignment: .trailing)
            } else {
                Color.clear.frame(width: 64, height: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? .green : .orange)
                    Text(task.title ?? "Задача")
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }

                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Detail sheet
private struct CalendarDetailSheet: View {
    let detail: CalendarScreen.CalendarDetail
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                switch detail {
                case .event(let event):
                    eventContent(event)
                case .task(let task):
                    taskContent(task)
                }
            }
            .padding()
            .navigationTitle("Подробности")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private func eventContent(_ event: EventEntity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(event.title ?? "Событие")
                .font(.title2)
                .fontWeight(.semibold)
            if let start = event.startDate {
                let end = event.endDate ?? start.addingTimeInterval(3600)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Дата")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(eventDateFormatter.string(from: start))
                    Text("\(eventTimeFormatter.string(from: start)) – \(eventTimeFormatter.string(from: end))")
                        .foregroundColor(.secondary)
                }
            }
            if let notes = event.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Описание")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(notes)
                }
            }
            Spacer()
        }
    }

    private func taskContent(_ task: TaskEntity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(task.title ?? "Задача")
                .font(.title2)
                .fontWeight(.semibold)
            if let due = task.dueDate {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Дедлайн")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(eventDateFormatter.string(from: due))
                    Text(eventTimeFormatter.string(from: due))
                        .foregroundColor(.secondary)
                }
            }
            if let notes = task.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Заметки")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(notes)
                }
            }
            Spacer()
        }
    }

    private var eventDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .long
        return formatter
    }

    private var eventTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Formatters
private extension CalendarScreen {
    var viewModeBinding: Binding<CalendarViewMode> {
        Binding(
            get: { viewModel.viewMode },
            set: { viewModel.switchViewMode($0) }
        )
    }

    var longDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }

    var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter
    }

    var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE"
        return formatter
    }

    var weekdayShortFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEE"
        return formatter
    }

    var dayNumberFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }

    var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }

    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeStyle = .short
        return formatter
    }
}

#Preview {
    CalendarScreen(viewModel: CalendarViewModel(context: PersistenceController.preview().container.viewContext))
}
