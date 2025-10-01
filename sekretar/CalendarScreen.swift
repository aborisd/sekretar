import SwiftUI
import CoreData

struct CalendarScreen: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var viewModel: CalendarViewModel
    @State private var presentedDetail: CalendarDetail?
    @State private var highlightedTimelineItem: NSManagedObjectID?
    @State private var highlightResetTask: Task<Void, Never>?

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
            .background(DesignSystem.Colors.background)
            .navigationTitle("Календарь")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сегодня") { viewModel.goToToday() }
                        .font(.callout)
                }
            }
#endif
#endif
            .onReceive(NotificationCenter.default.publisher(for: .focusCalendarDate)) { note in
                if let date = note.userInfo?["date"] as? Date {
                    viewModel.selectDate(date)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .aiDidApplyAction)) { note in
                if let date = note.userInfo?["date"] as? Date {
                    viewModel.selectDate(date)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .highlightCalendarItem)) { note in
                handleHighlightNotification(note)
            }
            .onDisappear { highlightResetTask?.cancel() }
            .sheet(item: $presentedDetail) { detail in
                switch detail {
                case .event(let event):
                    EventEditorView(event: event)
                        .environment(\.managedObjectContext, context)
                case .task(let task):
                    TaskEditorView(task: task)
                        .environment(\.managedObjectContext, context)
                }
            }
        }
    }
}

// MARK: - Subviews
private extension CalendarScreen {
    func handleHighlightNotification(_ note: Notification) {
        if let date = note.userInfo?["date"] as? Date {
            viewModel.selectDate(date)
        }
        if let id = note.userInfo?["id"] as? NSManagedObjectID {
            triggerHighlight(for: id)
        }
    }

    func triggerHighlight(for id: NSManagedObjectID) {
        highlightedTimelineItem = id
        highlightResetTask?.cancel()
        highlightResetTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                if highlightedTimelineItem == id {
                    highlightedTimelineItem = nil
                }
            }
        }
    }

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
        .background(DesignSystem.Colors.secondaryBackground)
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
        .background(platformAgendaBackground)
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
        DayTimelineView(
            date: viewModel.selectedDate,
            events: viewModel.eventsFor(date: viewModel.selectedDate),
            tasks: viewModel.tasksFor(date: viewModel.selectedDate),
            highlightedID: highlightedTimelineItem,
            onSelectEvent: { presentedDetail = .event($0) },
            onSelectTask: { presentedDetail = .task($0) }
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
        .background(DesignSystem.Colors.secondaryBackground)
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
        var indicators: [Color] = []

        let tasks = viewModel.tasksFor(date: date)
        let priorityOrder: [Int16] = [3, 2, 1]

        for priority in priorityOrder {
            if tasks.contains(where: { $0.priority == priority }) {
                indicators.append(priorityColor(for: priority))
            }
        }

        if indicators.count < 3, tasks.contains(where: { $0.priority <= 0 }) {
            indicators.append(priorityColor(for: 0))
        }

        if indicators.count < 3, !viewModel.eventsFor(date: date).isEmpty {
            indicators.append(.blue)
        }

        return Array(indicators.prefix(3))
    }

    private func priorityColor(for priority: Int16) -> Color {
        switch priority {
        case 3: return DesignSystem.Colors.priorityHigh
        case 2: return DesignSystem.Colors.priorityMedium
        case 1: return DesignSystem.Colors.priorityLow
        default: return DesignSystem.Colors.priorityNone
        }
    }

    private var platformAgendaBackground: Color { DesignSystem.Colors.secondaryBackground }
}

// MARK: - Day timeline
private struct DayTimelineView: View {
    let date: Date
    let events: [EventEntity]
    let tasks: [TaskEntity]
    let highlightedID: NSManagedObjectID?
    let onSelectEvent: (EventEntity) -> Void
    let onSelectTask: (TaskEntity) -> Void

    private let hourHeight: CGFloat = 52
    private let minBlockHeight: CGFloat = 48
    private let columnSpacing: CGFloat = 8
    private let calendar = Calendar.current
    @State private var highlightAlpha: Double = 0

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !allDayEvents.isEmpty {
                allDayRibbon
            }

            HStack(alignment: .top, spacing: 12) {
                hoursColumn
                timelineContent
            }
        }
        .padding(.vertical, 12)
        .padding(.trailing, 12)
        .padding(.leading, 16)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray.opacity(0.15))
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: layoutItems)
        .onChange(of: highlightToken) { _ in updateHighlightAnimation() }
        .onAppear { updateHighlightAnimation() }
    }

    private var allDayEvents: [EventEntity] {
        events.filter { $0.isAllDay }
    }

    private var timedEvents: [EventEntity] {
        events.filter { !$0.isAllDay }
    }

    private var layoutItems: [TimelineLayoutItem] {
        let eventInputs = timedEvents.compactMap { event -> DayTimelineLayout.Input? in
            guard let start = event.startDate else { return nil }
            let end = event.endDate ?? start.addingTimeInterval(3600)
            return .init(id: event.objectID, type: .event, start: start, end: end)
        }

        let taskInputs = tasks.compactMap { task -> DayTimelineLayout.Input? in
            guard let due = task.dueDate else { return nil }
            let duration = taskDuration(for: task)
            return .init(id: task.objectID, type: .task, start: due, end: due.addingTimeInterval(duration))
        }

        return DayTimelineLayout().layout(inputs: eventInputs + taskInputs)
    }

    private var highlightToken: String {
        highlightedID?.uriRepresentation().absoluteString ?? ""
    }

    private var timelineContent: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let items = layoutItems

            ZStack(alignment: .topLeading) {
                gridBackground(width: width)

                ForEach(items) { item in
                    blockView(for: item, totalWidth: width)
                }

                if let indicatorY = currentTimeOffset {
                    currentTimeIndicator(width: width)
                        .offset(y: indicatorY)
                        .transition(.opacity)
                }
            }
            .frame(height: timelineHeight)
        }
        .frame(height: timelineHeight)
    }

    @ViewBuilder
    private func blockView(for item: TimelineLayoutItem, totalWidth: CGFloat) -> some View {
        let width = blockWidth(for: item, totalWidth: totalWidth)
        let height = blockHeight(for: item)
        let x = xOffset(for: item, totalWidth: totalWidth)
        let y = yOffset(for: item.start)

        switch item.type {
        case .event:
            if let event = event(for: item.id) {
                eventBlock(event, layout: item, height: height)
                    .frame(width: width, height: height, alignment: .topLeading)
                    .offset(x: x, y: y)
                    .transition(.scale.combined(with: .opacity))
            }
        case .task:
            if let task = task(for: item.id) {
                taskBlock(task, height: height)
                    .frame(width: width, height: height, alignment: .topLeading)
                    .offset(x: x, y: y)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var timelineHeight: CGFloat { hourHeight * 24 }

    private var currentTimeOffset: CGFloat? {
        guard calendar.isDate(Date(), inSameDayAs: date) else { return nil }
        return offset(for: Date())
    }

    private var allDayRibbon: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Весь день")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(allDayEvents, id: \.objectID) { event in
                        Button {
                            onSelectEvent(event)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sun.max.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text(event.title ?? "Событие")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primaryBlue.opacity(0.88),
                                        DesignSystem.Colors.primaryTeal.opacity(0.82)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .shadow(color: DesignSystem.Colors.primaryBlue.opacity(0.25), radius: 6, x: 0, y: 3)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 4)
    }

    private var hoursColumn: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(0..<24) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(height: hourHeight, alignment: .topTrailing)
            }
        }
        .frame(width: 48)
    }

    private func gridBackground(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                for hour in 0...24 {
                    let y = CGFloat(hour) * hourHeight
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.15), lineWidth: 1)

            Path { path in
                for half in 0..<24 {
                    let y = CGFloat(half) * hourHeight + hourHeight / 2
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width * 0.82, y: y))
                }
            }
            .stroke(style: StrokeStyle(lineWidth: 0.6, dash: [4, 6], dashPhase: 2))
            .foregroundColor(Color.gray.opacity(0.08))
        }
    }

    private func currentTimeIndicator(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.red.opacity(0.5))
                .frame(width: width, height: 2)

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.red.opacity(0.35), radius: 4)
                Text("Сейчас")
                    .font(.caption2.bold())
                    .foregroundColor(Color.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white)
                            .shadow(color: Color.red.opacity(0.12), radius: 4, x: 0, y: 2)
                    )
            }
        }
    }

    private func eventBlock(_ event: EventEntity, layout: TimelineLayoutItem, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(event.title ?? "Событие")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if layout.columnCount > 1 {
                    Text("×\(layout.columnCount - 1)")
                        .font(.caption2.bold())
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.18))
                        )
                }
            }

            if let timeRange = timeRangeText(for: event) {
                Text(timeRange)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }

            if let notes = event.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primaryBlue.opacity(0.85),
                            DesignSystem.Colors.primaryTeal.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .overlay(highlightOverlay(for: layout.id))
        .shadow(color: DesignSystem.Colors.primaryBlue.opacity(0.25), radius: 8, x: 0, y: 4)
        .onTapGesture { onSelectEvent(event) }
    }

    private func taskBlock(_ task: TaskEntity, height: CGFloat) -> some View {
        let color = taskColor(for: task.priority)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(color)
                    .imageScale(.medium)
                Text(task.title ?? "Задача")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if task.priority > 0 {
                    Text(priorityLabel(for: task.priority))
                        .font(.caption2.bold())
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(color.opacity(0.18))
                        )
                }
            }

            if let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }

            if let due = task.dueDate {
                Text("Срок: \(Self.timeFormatter.string(from: due))")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.9))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1.2)
        )
        .overlay(highlightOverlay(for: task.objectID))
        .shadow(color: color.opacity(0.12), radius: 6, x: 0, y: 3)
        .onTapGesture { onSelectTask(task) }
    }

    private func highlightOverlay(for id: NSManagedObjectID) -> some View {
        let opacity = highlightOpacity(for: id)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.yellow, lineWidth: 3)
            .opacity(opacity)
            .shadow(color: Color.yellow.opacity(opacity * 0.6), radius: opacity > 0 ? 12 : 0)
    }

    private func highlightOpacity(for id: NSManagedObjectID) -> Double {
        guard let highlightedID else { return 0 }
        return highlightedID == id ? highlightAlpha : 0
    }

    private func event(for id: NSManagedObjectID) -> EventEntity? {
        events.first { $0.objectID == id }
    }

    private func task(for id: NSManagedObjectID) -> TaskEntity? {
        tasks.first { $0.objectID == id }
    }

    private func timeRangeText(for event: EventEntity) -> String? {
        guard let start = event.startDate else { return nil }
        let end = event.endDate ?? start.addingTimeInterval(3600)
        return "\(Self.timeFormatter.string(from: start)) – \(Self.timeFormatter.string(from: end))"
    }

    private func blockWidth(for item: TimelineLayoutItem, totalWidth: CGFloat) -> CGFloat {
        let columns = max(1, CGFloat(item.columnCount))
        let gaps = columnSpacing * (columns - 1)
        let width = (totalWidth - gaps) / columns
        return max(width, 0)
    }

    private func xOffset(for item: TimelineLayoutItem, totalWidth: CGFloat) -> CGFloat {
        let width = blockWidth(for: item, totalWidth: totalWidth)
        return CGFloat(item.column) * (width + columnSpacing)
    }

    private func blockHeight(for item: TimelineLayoutItem) -> CGFloat {
        let height = durationHeight(from: item.start, to: item.end)
        return max(height, minBlockHeight)
    }

    private func yOffset(for date: Date) -> CGFloat {
        offset(for: date)
    }

    private func offset(for date: Date) -> CGFloat {
        let startOfDay = calendar.startOfDay(for: self.date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let clamped = min(max(date, startOfDay), endOfDay)
        let minutes = calendar.dateComponents([.minute], from: startOfDay, to: clamped).minute ?? 0
        return CGFloat(minutes) / 60 * hourHeight
    }

    private func durationHeight(from start: Date, to end: Date) -> CGFloat {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let clampedStart = max(start, startOfDay)
        let clampedEnd = min(end, endOfDay)
        let minutes = max(20, calendar.dateComponents([.minute], from: clampedStart, to: clampedEnd).minute ?? 0)
        return CGFloat(minutes) / 60 * hourHeight
    }

    private func taskDuration(for task: TaskEntity) -> TimeInterval {
        switch task.priority {
        case 3: return 75 * 60
        case 2: return 50 * 60
        case 1: return 35 * 60
        default: return 30 * 60
        }
    }

    private func updateHighlightAnimation() {
        guard highlightedID != nil else {
            highlightAlpha = 0
            return
        }
        highlightAlpha = 0.95
        withAnimation(.easeOut(duration: 2.2)) {
            highlightAlpha = 0
        }
    }

    private func taskColor(for priority: Int16) -> Color {
        switch priority {
        case 3: return DesignSystem.Colors.priorityHigh
        case 2: return DesignSystem.Colors.priorityMedium
        case 1: return DesignSystem.Colors.priorityLow
        default: return DesignSystem.Colors.priorityNone
        }
    }

    private func priorityLabel(for value: Int16) -> String {
        switch value {
        case 3: return "Высокий"
        case 2: return "Средний"
        case 1: return "Низкий"
        default: return "Без приоритета"
        }
    }

    private struct TimelineLayoutItem: Identifiable, Hashable {
        enum ItemType: Hashable { case event, task }
        let id: NSManagedObjectID
        let type: ItemType
        let start: Date
        let end: Date
        let column: Int
        let columnCount: Int
    }

    private struct DayTimelineLayout {
        struct Input {
            let id: NSManagedObjectID
            let type: TimelineLayoutItem.ItemType
            let start: Date
            let end: Date
        }

        func layout(inputs: [Input]) -> [TimelineLayoutItem] {
            guard !inputs.isEmpty else { return [] }

            let sorted = inputs.sorted {
                if $0.start == $1.start {
                    return $0.end < $1.end
                }
                return $0.start < $1.start
            }

            var active: [Intermediate] = []
            var results: [Intermediate] = []

            for input in sorted {
                active.removeAll { $0.input.end <= input.start }

                let usedColumns = Set(active.map { $0.column })
                var column = 0
                while usedColumns.contains(column) { column += 1 }

                let group = active.first?.group ?? UUID()
                let entry = Intermediate(input: input, column: column, group: group)
                active.append(entry)
                results.append(entry)
            }

            let groupColumns = results.reduce(into: [UUID: Int]()) { partial, entry in
                let current = partial[entry.group] ?? 0
                partial[entry.group] = max(current, entry.column + 1)
            }

            return results.map { entry in
                TimelineLayoutItem(
                    id: entry.input.id,
                    type: entry.input.type,
                    start: entry.input.start,
                    end: entry.input.end,
                    column: entry.column,
                    columnCount: groupColumns[entry.group] ?? 1
                )
            }
        }

        private struct Intermediate {
            let input: Input
            let column: Int
            let group: UUID
        }
    }
}

// MARK: - Agenda row builder
private struct AgendaRowBuilder {
    let timeFormatter: DateFormatter

    func eventRow(event: EventEntity) -> some View {
        HStack(alignment: .center, spacing: 14) {
            if let start = event.startDate {
                let end = event.endDate ?? start.addingTimeInterval(3600)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(timeFormatter.string(from: start))
                        .font(.subheadline.weight(.semibold))
                    Text(timeFormatter.string(from: end))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 56, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text(event.title ?? "Событие")
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    func taskRow(task: TaskEntity) -> some View {
        HStack(alignment: .center, spacing: 14) {
            if let due = task.dueDate {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(timeFormatter.string(from: due))
                        .font(.subheadline.weight(.semibold))
                    if task.priority > 0 {
                        Text("P\(task.priority)")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .frame(width: 56, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? .green : DesignSystem.Colors.priorityMedium)
                    Text(task.title ?? "Задача")
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .strikethrough(task.isCompleted, color: DesignSystem.Colors.textSecondary)
                }

                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
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
