import WidgetKit
import SwiftUI
import CoreData

// MARK: - Today Tasks Widget (BRD строка 56, 269)
/// Виджет "Сегодня" - показывает задачи на сегодня
struct TodayTasksWidget: Widget {
    let kind: String = "TodayTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayTasksProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Tasks Today")
        .description("View your tasks for today")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Quick Add Widget
/// Виджет "Быстро добавить" - кнопка для быстрого добавления задачи
struct QuickAddWidget: Widget {
    let kind: String = "QuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAddProvider()) { entry in
            QuickAddWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Add Task")
        .description("Quickly add a new task")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Next Task Widget
/// Виджет "Следующая задача" - показывает самую приоритетную задачу
struct NextTaskWidget: Widget {
    let kind: String = "NextTaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextTaskProvider()) { entry in
            NextTaskWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Task")
        .description("Show your next priority task")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Today Tasks Provider
struct TodayTasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayTasksEntry {
        TodayTasksEntry(date: Date(), tasks: sampleTasks())
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayTasksEntry) -> Void) {
        let entry = TodayTasksEntry(date: Date(), tasks: sampleTasks())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayTasksEntry>) -> Void) {
        Task {
            let tasks = await fetchTodayTasks()
            let entry = TodayTasksEntry(date: Date(), tasks: tasks)

            // Обновляем каждые 15 минут
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchTodayTasks() async -> [WidgetTask] {
        let context = PersistenceController.shared.container.viewContext
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "isCompleted == NO AND (dueDate >= %@ AND dueDate < %@ OR dueDate == nil)",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "dueDate", ascending: true)
        ]
        request.fetchLimit = 10

        do {
            let taskEntities = try await context.perform { try context.fetch(request) }
            return taskEntities.compactMap { entity in
                guard let id = entity.id, let title = entity.title else { return nil }
                return WidgetTask(
                    id: id,
                    title: title,
                    priority: Int(entity.priority),
                    dueDate: entity.dueDate,
                    isCompleted: entity.isCompleted
                )
            }
        } catch {
            print("❌ Error fetching today tasks for widget: \(error)")
            return []
        }
    }

    private func sampleTasks() -> [WidgetTask] {
        [
            WidgetTask(id: UUID(), title: "Review project proposal", priority: 3, dueDate: Date(), isCompleted: false),
            WidgetTask(id: UUID(), title: "Call team meeting", priority: 2, dueDate: Date(), isCompleted: false),
            WidgetTask(id: UUID(), title: "Update documentation", priority: 1, dueDate: nil, isCompleted: false)
        ]
    }
}

// MARK: - Quick Add Provider
struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry {
        QuickAddEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        let entry = QuickAddEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Next Task Provider
struct NextTaskProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextTaskEntry {
        NextTaskEntry(date: Date(), task: sampleTask())
    }

    func getSnapshot(in context: Context, completion: @escaping (NextTaskEntry) -> Void) {
        let entry = NextTaskEntry(date: Date(), task: sampleTask())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextTaskEntry>) -> Void) {
        Task {
            let task = await fetchNextTask()
            let entry = NextTaskEntry(date: Date(), task: task)

            // Обновляем каждые 15 минут
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchNextTask() async -> WidgetTask? {
        let context = PersistenceController.shared.container.viewContext

        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == NO")
        request.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "dueDate", ascending: true)
        ]
        request.fetchLimit = 1

        do {
            let taskEntities = try await context.perform { try context.fetch(request) }
            guard let entity = taskEntities.first,
                  let id = entity.id,
                  let title = entity.title else { return nil }

            return WidgetTask(
                id: id,
                title: title,
                priority: Int(entity.priority),
                dueDate: entity.dueDate,
                isCompleted: entity.isCompleted
            )
        } catch {
            print("❌ Error fetching next task for widget: \(error)")
            return nil
        }
    }

    private func sampleTask() -> WidgetTask {
        WidgetTask(
            id: UUID(),
            title: "Complete project milestone",
            priority: 3,
            dueDate: Date(),
            isCompleted: false
        )
    }
}

// MARK: - Widget Entries
struct TodayTasksEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
}

struct QuickAddEntry: TimelineEntry {
    let date: Date
}

struct NextTaskEntry: TimelineEntry {
    let date: Date
    let task: WidgetTask?
}

// MARK: - Widget Models
struct WidgetTask: Identifiable {
    let id: UUID
    let title: String
    let priority: Int
    let dueDate: Date?
    let isCompleted: Bool

    var priorityColor: Color {
        switch priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .yellow
        default: return .gray
        }
    }

    var dueTimeText: String? {
        guard let dueDate = dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }
}

// MARK: - Widget Views

// Today Tasks Widget View
struct TodayTasksWidgetView: View {
    var entry: TodayTasksEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallTodayView(tasks: entry.tasks)
        case .systemMedium:
            MediumTodayView(tasks: entry.tasks)
        case .systemLarge:
            LargeTodayView(tasks: entry.tasks)
        default:
            SmallTodayView(tasks: entry.tasks)
        }
    }
}

struct SmallTodayView: View {
    let tasks: [WidgetTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .font(.headline)
                Text("Today")
                    .font(.headline)
                    .bold()
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            if tasks.isEmpty {
                Text("No tasks today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(tasks.prefix(3)) { task in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(task.priorityColor)
                            .frame(width: 6, height: 6)

                        Text(task.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct MediumTodayView: View {
    let tasks: [WidgetTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .font(.title2)
                Text("Today's Tasks")
                    .font(.title3)
                    .bold()
                Spacer()
                Text("\(tasks.count) tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            if tasks.isEmpty {
                Text("No tasks scheduled for today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(tasks.prefix(5)) { task in
                    HStack {
                        Circle()
                            .fill(task.priorityColor)
                            .frame(width: 8, height: 8)

                        Text(task.title)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        if let time = task.dueTimeText {
                            Text(time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct LargeTodayView: View {
    let tasks: [WidgetTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text("Today's Tasks")
                        .font(.title2)
                        .bold()
                    Text(Date(), style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(tasks.count)")
                    .font(.title)
                    .bold()
                    .foregroundColor(.blue)
            }

            Divider()

            if tasks.isEmpty {
                VStack {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("All done for today!")
                        .font(.headline)
                    Text("No tasks scheduled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(tasks) { task in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(task.priorityColor)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.subheadline)
                                .lineLimit(2)

                            if let time = task.dueTimeText {
                                Text(time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// Quick Add Widget View
struct QuickAddWidgetView: View {
    var entry: QuickAddEntry

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.blue)

            Text("Add Task")
                .font(.headline)
                .bold()

            Text("Tap to create")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .widgetURL(URL(string: "sekretar://add-task"))
    }
}

// Next Task Widget View
struct NextTaskWidgetView: View {
    var entry: NextTaskEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let task = entry.task {
            switch family {
            case .systemSmall:
                SmallNextTaskView(task: task)
            case .systemMedium:
                MediumNextTaskView(task: task)
            default:
                SmallNextTaskView(task: task)
            }
        } else {
            NoTaskView()
        }
    }
}

struct SmallNextTaskView: View {
    let task: WidgetTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(task.priorityColor)
                Text("Next")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Text(task.title)
                .font(.subheadline)
                .bold()
                .lineLimit(3)

            Spacer()

            if let time = task.dueTimeText {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(time)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct MediumNextTaskView: View {
    let task: WidgetTask

    var body: some View {
        HStack(spacing: 16) {
            VStack {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(task.priorityColor)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Next Priority Task")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(task.title)
                    .font(.headline)
                    .bold()
                    .lineLimit(2)

                Spacer()

                if let time = task.dueTimeText {
                    HStack {
                        Image(systemName: "clock")
                        Text(time)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct NoTaskView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)

            Text("All Done!")
                .font(.headline)
                .bold()

            Text("No pending tasks")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Widget Bundle
// Note: Widgets should be in separate target with @main
// For now, widgets are defined but not activated
// TODO: Create Widget Extension target in Xcode
struct SekretarWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayTasksWidget()
        QuickAddWidget()
        NextTaskWidget()
    }
}
