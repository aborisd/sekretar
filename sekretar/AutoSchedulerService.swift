import Foundation
import CoreData
import EventKit
import SwiftUI

// MARK: - Auto Scheduler Service
/// Автоматическое планирование задач в свободные слоты календаря
/// Реализует алгоритм умных слотов из BRD (строки 325-344)
@MainActor
final class AutoSchedulerService: ObservableObject {
    static let shared = AutoSchedulerService()

    @Published var suggestedSlots: [TimeSlot] = []
    @Published var isAnalyzing = false

    private let eventStore = EKEventStore()
    private let calendar = Calendar.current

    // MARK: - User Preferences (будут из UserDefaults/Core Data)
    struct UserPreferences {
        var deepWorkHours: [DateInterval] = [] // Часы глубокой работы
        var quietHours: [DateInterval] = []    // Тихие часы (не беспокоить)
        var workDayStart: Int = 9              // Начало рабочего дня (часы)
        var workDayEnd: Int = 18               // Конец рабочего дня (часы)
        var minSlotDuration: TimeInterval = 900 // Минимальная длительность слота (15 мин)
        var maxSlotDuration: TimeInterval = 14400 // Максимальная длительность слота (4 часа)
    }

    private var userPrefs = UserPreferences()

    private init() {
        loadUserPreferences()
    }

    // MARK: - Main Algorithm: Smart Time Slots
    /// Алгоритм умных слотов (BRD строки 325-344)
    /// 1. Сформировать кандидаты из свободных окон
    /// 2. Отфильтровать по длительности, дедлайну, приоритету
    /// 3. Отсортировать: приоритет → дедлайн → deepWork → фрагментация
    /// 4. Предложить топ-3
    func suggestTimeSlots(
        for task: TaskEntity,
        requiredDuration: TimeInterval? = nil,
        deadline: Date? = nil,
        searchRange: DateInterval? = nil,
        context: NSManagedObjectContext
    ) async -> [TimeSlot] {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // Определяем параметры поиска
        let duration = requiredDuration ?? estimateTaskDuration(task)
        let taskDeadline = deadline ?? task.dueDate ?? Date().addingTimeInterval(7 * 86400) // +7 дней по умолчанию
        let range = searchRange ?? DateInterval(
            start: Date(),
            end: taskDeadline
        )

        // Шаг 1: Сформировать кандидаты из свободных окон
        let freeWindows = await findFreeWindows(in: range, context: context)

        // Шаг 2: Отфильтровать по длительности, дедлайну, приоритету
        let candidateSlots = filterCandidateSlots(
            freeWindows: freeWindows,
            requiredDuration: duration,
            deadline: taskDeadline,
            task: task
        )

        // Шаг 3: Отсортировать по критериям
        let sortedSlots = sortSlotsByCriteria(
            candidateSlots,
            task: task,
            deadline: taskDeadline
        )

        // Шаг 4: Вернуть топ-3
        let topSlots = Array(sortedSlots.prefix(3))

        suggestedSlots = topSlots

        AnalyticsService.shared.track(.smartSlotsGenerated, properties: [
            "task_priority": Int(task.priority),
            "slots_found": topSlots.count,
            "required_duration": duration
        ])

        return topSlots
    }

    // MARK: - Step 1: Find Free Windows
    /// Находит свободные окна в календаре с учетом:
    /// - Занятых событий из EventKit
    /// - Существующих задач из Core Data
    /// - DeepWork/QuietHours из настроек
    private func findFreeWindows(
        in range: DateInterval,
        context: NSManagedObjectContext
    ) async -> [DateInterval] {
        var freeWindows: [DateInterval] = []

        // Получаем занятые интервалы
        let busyIntervals = await getBusyIntervals(in: range, context: context)

        // Разбиваем диапазон на дни
        var currentDate = range.start

        while currentDate < range.end {
            let dayStart = calendar.startOfDay(for: currentDate)
            let workStart = calendar.date(bySettingHour: userPrefs.workDayStart, minute: 0, second: 0, of: dayStart)!
            let workEnd = calendar.date(bySettingHour: userPrefs.workDayEnd, minute: 0, second: 0, of: dayStart)!

            let dayRange = DateInterval(start: workStart, end: workEnd)

            // Находим свободные слоты в этом дне
            let dayFreeSlots = findFreeSlotsInDay(dayRange: dayRange, busyIntervals: busyIntervals)
            freeWindows.append(contentsOf: dayFreeSlots)

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return freeWindows
    }

    /// Получает все занятые интервалы (EventKit + Core Data задачи)
    private func getBusyIntervals(
        in range: DateInterval,
        context: NSManagedObjectContext
    ) async -> [DateInterval] {
        var busyIntervals: [DateInterval] = []

        // 1. EventKit события
        if #available(macOS 14.0, iOS 17.0, *) {
            guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return busyIntervals }
        } else {
            guard EKEventStore.authorizationStatus(for: .event) == .authorized else { return busyIntervals }
        }

        let predicate = eventStore.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
        let events = eventStore.events(matching: predicate)

        for event in events {
            let interval = DateInterval(start: event.startDate, end: event.endDate)
            busyIntervals.append(interval)
        }

        // 2. Запланированные задачи из Core Data
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "dueDate != nil AND isCompleted == NO AND dueDate >= %@ AND dueDate <= %@",
            range.start as CVarArg,
            range.end as CVarArg
        )

        do {
            let tasks = try context.fetch(request)
            for task in tasks {
                guard let taskDate = task.dueDate else { continue }
                let duration = estimateTaskDuration(task)
                let interval = DateInterval(start: taskDate, duration: duration)
                busyIntervals.append(interval)
            }
        } catch {
            print("❌ Error fetching tasks for busy intervals: \(error)")
        }

        // Сортируем по времени начала
        busyIntervals.sort { $0.start < $1.start }

        return busyIntervals
    }

    /// Находит свободные слоты в одном дне
    private func findFreeSlotsInDay(
        dayRange: DateInterval,
        busyIntervals: [DateInterval]
    ) -> [DateInterval] {
        var freeSlots: [DateInterval] = []
        var currentTime = dayRange.start

        // Фильтруем занятые интервалы для этого дня
        let relevantBusy = busyIntervals.filter { busy in
            busy.start < dayRange.end && busy.end > dayRange.start
        }

        for busy in relevantBusy {
            // Если есть свободное время до следующего занятого интервала
            if currentTime < busy.start {
                let freeInterval = DateInterval(start: currentTime, end: busy.start)
                if freeInterval.duration >= userPrefs.minSlotDuration {
                    freeSlots.append(freeInterval)
                }
            }
            currentTime = max(currentTime, busy.end)
        }

        // Проверяем свободное время после последнего занятого интервала
        if currentTime < dayRange.end {
            let freeInterval = DateInterval(start: currentTime, end: dayRange.end)
            if freeInterval.duration >= userPrefs.minSlotDuration {
                freeSlots.append(freeInterval)
            }
        }

        return freeSlots
    }

    // MARK: - Step 2: Filter Candidates
    /// Фильтрует кандидаты по длительности, дедлайну, приоритету
    private func filterCandidateSlots(
        freeWindows: [DateInterval],
        requiredDuration: TimeInterval,
        deadline: Date,
        task: TaskEntity
    ) -> [TimeSlot] {
        var candidates: [TimeSlot] = []

        for window in freeWindows {
            // Фильтр 1: Достаточная длительность
            guard window.duration >= requiredDuration else { continue }

            // Фильтр 2: До дедлайна
            guard window.start < deadline else { continue }

            // Фильтр 3: Не превышает максимальную длительность
            let slotDuration = min(window.duration, requiredDuration, userPrefs.maxSlotDuration)
            let slotEnd = window.start.addingTimeInterval(slotDuration)

            let slot = TimeSlot(
                start: window.start,
                end: slotEnd,
                duration: slotDuration,
                taskId: task.id,
                priority: Int(task.priority),
                isDeepWorkTime: isDeepWorkTime(window.start),
                fragmentationScore: calculateFragmentationScore(window)
            )

            candidates.append(slot)
        }

        return candidates
    }

    // MARK: - Step 3: Sort by Criteria
    /// Сортирует слоты по критериям (BRD строка 339-340):
    /// - Приоритет (P0 > P1 > P2 > P3)
    /// - Раньше дедлайн
    /// - Внутри deepWork
    /// - Меньшая фрагментация дня
    private func sortSlotsByCriteria(
        _ slots: [TimeSlot],
        task: TaskEntity,
        deadline: Date
    ) -> [TimeSlot] {
        return slots.sorted { slot1, slot2 in
            // 1. Приоритет (выше = лучше)
            if slot1.priority != slot2.priority {
                return slot1.priority > slot2.priority
            }

            // 2. Раньше дедлайн (ближе к сегодня = лучше)
            let timeToDeadline1 = deadline.timeIntervalSince(slot1.start)
            let timeToDeadline2 = deadline.timeIntervalSince(slot2.start)
            if abs(timeToDeadline1 - timeToDeadline2) > 3600 { // Разница > 1 часа
                return timeToDeadline1 > timeToDeadline2
            }

            // 3. DeepWork время (лучше)
            if slot1.isDeepWorkTime != slot2.isDeepWorkTime {
                return slot1.isDeepWorkTime
            }

            // 4. Меньшая фрагментация дня
            return slot1.fragmentationScore < slot2.fragmentationScore
        }
    }

    // MARK: - Helper Methods

    /// Оценка длительности задачи
    private func estimateTaskDuration(_ task: TaskEntity) -> TimeInterval {
        // Базовая длительность по приоритету
        let baseDuration: TimeInterval = switch Int(task.priority) {
        case 3: 3600      // High priority: 1 час
        case 2: 1800      // Medium priority: 30 минут
        case 1: 900       // Low priority: 15 минут
        default: 1200     // No priority: 20 минут
        }

        // Корректировка по сложности (длина заметок)
        let notesLength = task.notes?.count ?? 0
        let complexityMultiplier = 1.0 + (Double(notesLength) / 500.0)

        return baseDuration * complexityMultiplier
    }

    /// Проверяет, попадает ли время в DeepWork часы
    private func isDeepWorkTime(_ date: Date) -> Bool {
        for deepWorkInterval in userPrefs.deepWorkHours {
            if deepWorkInterval.contains(date) {
                return true
            }
        }
        return false
    }

    /// Вычисляет оценку фрагментации (чем меньше, тем лучше)
    /// Слоты в начале дня и длинные слоты получают низкую оценку
    private func calculateFragmentationScore(_ window: DateInterval) -> Double {
        let hour = calendar.component(.hour, from: window.start)

        // Предпочитаем утренние часы (9-12)
        let timeScore = Double(abs(hour - 10)) // Оптимум в 10:00

        // Предпочитаем длинные непрерывные слоты
        let durationScore = 1000.0 / max(window.duration, 1.0)

        return timeScore + durationScore
    }

    /// Загрузка пользовательских настроек
    private func loadUserPreferences() {
        // TODO: Загрузка из UserDefaults/Core Data
        // Пока используем значения по умолчанию

        // Пример: DeepWork часы 9:00-12:00 каждый день
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        if let deepWorkStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay),
           let deepWorkEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay) {
            userPrefs.deepWorkHours = [DateInterval(start: deepWorkStart, end: deepWorkEnd)]
        }

        // QuietHours: 20:00-22:00
        if let quietStart = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: startOfDay),
           let quietEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: startOfDay) {
            userPrefs.quietHours = [DateInterval(start: quietStart, end: quietEnd)]
        }
    }

    // MARK: - Auto-Schedule Task
    /// Автоматически планирует задачу в лучший доступный слот
    func autoScheduleTask(
        _ task: TaskEntity,
        context: NSManagedObjectContext
    ) async throws {
        let slots = await suggestTimeSlots(for: task, context: context)

        guard let bestSlot = slots.first else {
            throw AutoSchedulerError.noSlotsAvailable
        }

        // Назначаем задаче время из лучшего слота
        task.dueDate = bestSlot.start
        task.updatedAt = Date()

        try context.save()

        // Планируем напоминание
        await NotificationService.scheduleTaskReminder(task)

        AnalyticsService.shared.track(.taskAutoScheduled, properties: [
            "task_priority": Int(task.priority),
            "slot_start": bestSlot.start.ISO8601Format(),
            "is_deep_work": bestSlot.isDeepWorkTime
        ])

        print("✅ Auto-scheduled task '\(task.title ?? "Task")' to \(bestSlot.start)")
    }

    // MARK: - Batch Auto-Schedule
    /// Планирует несколько задач одновременно с учётом взаимных конфликтов
    func autoScheduleTasks(
        _ tasks: [TaskEntity],
        context: NSManagedObjectContext
    ) async throws {
        // Сортируем задачи по приоритету и дедлайну
        let sortedTasks = tasks.sorted { task1, task2 in
            if task1.priority != task2.priority {
                return task1.priority > task2.priority
            }
            if let date1 = task1.dueDate, let date2 = task2.dueDate {
                return date1 < date2
            }
            return false
        }

        // Планируем по очереди (высокоприоритетные первыми)
        for task in sortedTasks {
            try await autoScheduleTask(task, context: context)
        }

        print("✅ Auto-scheduled \(tasks.count) tasks")
    }
}

// MARK: - Time Slot Model
struct TimeSlot: Identifiable, Hashable {
    let id = UUID()
    let start: Date
    let end: Date
    let duration: TimeInterval
    let taskId: UUID?
    let priority: Int
    let isDeepWorkTime: Bool
    let fragmentationScore: Double

    var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: start)
    }

    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TimeSlot, rhs: TimeSlot) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Errors
enum AutoSchedulerError: LocalizedError {
    case noSlotsAvailable
    case taskAlreadyScheduled
    case invalidDuration
    case deadlineTooSoon

    var errorDescription: String? {
        switch self {
        case .noSlotsAvailable:
            return "No available time slots found for this task"
        case .taskAlreadyScheduled:
            return "Task is already scheduled"
        case .invalidDuration:
            return "Invalid task duration"
        case .deadlineTooSoon:
            return "Deadline is too soon to schedule this task"
        }
    }
}

// MARK: - Analytics Extensions
extension AnalyticsEvent {
    static let smartSlotsGenerated = AnalyticsEvent(rawValue: "smart_slots_generated")!
    static let taskAutoScheduled = AnalyticsEvent(rawValue: "task_auto_scheduled")!
}
