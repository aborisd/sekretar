import Foundation
import UserNotifications
import CoreData
import BackgroundTasks

protocol NotificationServiceProtocol {
    static func requestAuthorization() async -> Bool
    static func scheduleTaskReminder(_ task: TaskEntity) async
    static func scheduleEventReminder(_ event: EventEntity) async
    static func cancelReminder(for taskID: UUID)
    static func scheduleSmartReminder(for task: TaskEntity, at date: Date) async
    static func setupNotificationCategories()
}

enum NotificationService: NotificationServiceProtocol {
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
                cont.resume(returning: ok)
            }
        }
    }

    static func scheduleTaskReminder(_ task: TaskEntity) async {
        guard let dueDate = task.dueDate, 
              let taskId = task.id,
              dueDate > Date(), 
              task.isCompleted == false else {
            if let taskId = task.id {
                cancelReminder(for: taskId)
            }
            return
        }
        
        let id = "task.\(taskId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = task.title ?? "Task"
        content.sound = .default
        content.userInfo = ["taskId": taskId.uuidString, "type": "task"]
        
        // Add priority-based category (corrected mapping)
        switch task.priority {
        case 3: content.categoryIdentifier = "HIGH_PRIORITY"
        case 2: content.categoryIdentifier = "MEDIUM_PRIORITY"
        case 1: content.categoryIdentifier = "NORMAL_PRIORITY"
        default: content.categoryIdentifier = "LOW_PRIORITY"
        }

        // Schedule 1 hour before due date
        let reminderDate = dueDate.addingTimeInterval(-3600)
        guard reminderDate > Date() else { return }
        
        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(req)
    }
    
    static func scheduleEventReminder(_ event: EventEntity) async {
        guard let eventId = event.id,
              let startDate = event.startDate else { return }
        
        let id = "event.\(eventId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        
        let content = UNMutableNotificationContent()
        content.title = "Event Reminder"
        content.body = event.title ?? "Event"
        content.sound = .default
        content.userInfo = ["eventId": eventId.uuidString, "type": "event"]
        
        // Schedule 15 minutes before event
        let reminderDate = startDate.addingTimeInterval(-900)
        guard reminderDate > Date() else { return }
        
        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(req)
    }

    static func cancelReminder(for taskID: UUID) {
        let id = "task.\(taskID.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }
    
    static func scheduleSmartReminder(for task: TaskEntity, at date: Date) async {
        guard let taskId = task.id else { return }
        
        let id = "smart.\(taskId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        
        let content = UNMutableNotificationContent()
        content.title = "Smart Reminder"
        content.body = "Don't forget: \(task.title ?? "Task")"
        content.sound = .default
        content.userInfo = ["taskId": taskId.uuidString, "type": "smart_reminder"]
        
        // Add priority-based urgency (corrected mapping)
        switch task.priority {
        case 3: content.categoryIdentifier = "HIGH_PRIORITY"
        case 2: content.categoryIdentifier = "MEDIUM_PRIORITY"
        case 1: content.categoryIdentifier = "NORMAL_PRIORITY"
        default: content.categoryIdentifier = "LOW_PRIORITY"
        }
        
        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(req)
    }
    
    static func setupNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_TASK",
            title: "Mark Complete",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_TASK",
            title: "Snooze 1 hour",
            options: []
        )
        
        let highPriorityCategory = UNNotificationCategory(
            identifier: "HIGH_PRIORITY",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let mediumPriorityCategory = UNNotificationCategory(
            identifier: "MEDIUM_PRIORITY",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        let lowPriorityCategory = UNNotificationCategory(
            identifier: "LOW_PRIORITY",
            actions: [completeAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            highPriorityCategory,
            mediumPriorityCategory,
            lowPriorityCategory
        ])
    }
}
