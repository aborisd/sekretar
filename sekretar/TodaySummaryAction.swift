import Foundation
import CoreData

// MARK: - Today Summary Action
extension AIIntentService {

    /// Show user's tasks and events for today in a beautiful format
    func generateTodaySummary() async -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        // Fetch today's tasks
        let tasks = await fetchTodayTasks(from: today, to: tomorrow)
        let events = await fetchTodayEvents(from: today, to: tomorrow)

        // Build beautiful summary
        var summary: [String] = []

        // Header
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        let dateString = formatter.string(from: Date())
        summary.append("📅 \(dateString)")
        summary.append("")

        // Events section
        if !events.isEmpty {
            summary.append("🗓 События (\(events.count)):")
            for event in events {
                let timeStr = formatEventTime(event)
                let title = event.title ?? "Без названия"
                let icon = getEventIcon(event)
                summary.append("\(icon) \(timeStr) — \(title)")
            }
            summary.append("")
        }

        // Tasks section
        if !tasks.isEmpty {
            let completed = tasks.filter { $0.isCompleted }.count
            summary.append("✅ Задачи (\(completed)/\(tasks.count) выполнено):")

            // High priority first
            let highPriority = tasks.filter { $0.priority >= 2 && !$0.isCompleted }
            if !highPriority.isEmpty {
                summary.append("🔴 Важные:")
                for task in highPriority {
                    let title = task.title ?? "Без названия"
                    summary.append("  • \(title)")
                }
            }

            // Normal tasks
            let normalTasks = tasks.filter { $0.priority < 2 && !$0.isCompleted }
            if !normalTasks.isEmpty {
                for task in normalTasks {
                    let title = task.title ?? "Без названия"
                    let icon = task.isCompleted ? "✓" : "•"
                    summary.append("  \(icon) \(title)")
                }
            }
        }

        // Statistics
        let totalItems = tasks.count + events.count
        if totalItems == 0 {
            summary = ["🎉 Сегодня у вас свободный день!"]
        } else {
            summary.append("")
            summary.append("📊 Всего: \(totalItems) \(pluralForm(totalItems, "пункт", "пункта", "пунктов"))")

            // Motivation
            if tasks.filter({ !$0.isCompleted }).count > 5 {
                summary.append("💪 Продуктивный день! Начните с самого важного.")
            } else if tasks.filter({ $0.isCompleted }).count == tasks.count && tasks.count > 0 {
                summary.append("🎉 Отличная работа! Все задачи выполнены!")
            }
        }

        return summary.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func fetchTodayTasks(from start: Date, to end: Date) async -> [TaskEntity] {
        let ctx = PersistenceController.shared.container.viewContext
        return await ctx.perform {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "(dueDate >= %@ AND dueDate < %@) OR (createdAt >= %@ AND createdAt < %@ AND dueDate == nil)",
                                           start as NSDate, end as NSDate, start as NSDate, end as NSDate)
            request.sortDescriptors = [
                NSSortDescriptor(key: "priority", ascending: false),
                NSSortDescriptor(key: "dueDate", ascending: true)
            ]
            return (try? ctx.fetch(request)) ?? []
        }
    }

    private func fetchTodayEvents(from start: Date, to end: Date) async -> [EventEntity] {
        let ctx = PersistenceController.shared.container.viewContext
        return await ctx.perform {
            let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
            request.predicate = NSPredicate(format: "startDate >= %@ AND startDate < %@",
                                           start as NSDate, end as NSDate)
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
            return (try? ctx.fetch(request)) ?? []
        }
    }

    private func formatEventTime(_ event: EventEntity) -> String {
        guard let start = event.startDate else { return "Весь день" }

        if event.isAllDay {
            return "Весь день"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"

        if let end = event.endDate {
            return "\(formatter.string(from: start))–\(formatter.string(from: end))"
        }
        return formatter.string(from: start)
    }

    private func getEventIcon(_ event: EventEntity) -> String {
        let title = (event.title ?? "").lowercased()
        if title.contains("встреч") || title.contains("meeting") { return "👥" }
        if title.contains("звон") || title.contains("call") { return "📞" }
        if title.contains("день рожд") || title.contains("birthday") { return "🎂" }
        if title.contains("deadline") || title.contains("дедлайн") { return "⏰" }
        return "📌"
    }

    private func pluralForm(_ count: Int, _ form1: String, _ form2: String, _ form5: String) -> String {
        let n = abs(count) % 100
        let n1 = n % 10
        if n > 10 && n < 20 { return form5 }
        if n1 > 1 && n1 < 5 { return form2 }
        if n1 == 1 { return form1 }
        return form5
    }
}

// MARK: - Intent Handler
extension AIIntentService {

    func handleShowTodayIntent() async -> AIAction {
        let summary = await generateTodaySummary()

        return AIAction(
            type: .requestClarification,  // Using this type to show text
            title: "Ваш день",
            description: summary,
            confidence: 1.0,
            requiresConfirmation: false,
            payload: ["answer": summary]
        )
    }
}