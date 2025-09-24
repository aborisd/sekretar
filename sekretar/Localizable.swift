import Foundation

// MARK: - Localization System
struct L10n {
    private static let bundle = Bundle.main
    
    static func string(_ key: String) -> String {
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    // MARK: - Common
    struct Common {
        static let cancel = L10n.string("common.cancel")
        static let done = L10n.string("common.done")
        static let delete = L10n.string("common.delete")
        static let save = L10n.string("common.save")
        static let edit = L10n.string("common.edit")
        static let add = L10n.string("common.add")
        static let none = L10n.string("common.none")
        static let yes = L10n.string("common.yes")
        static let no = L10n.string("common.no")
    }
    
    // MARK: - Tasks
    struct Tasks {
        static let title = L10n.string("tasks.title")
        static let newTask = L10n.string("tasks.new_task")
        static let editTask = L10n.string("tasks.edit_task")
        static let createTask = L10n.string("tasks.create_task")
        static let saveChanges = L10n.string("tasks.save_changes")
        static let deleteTask = L10n.string("tasks.delete_task")
        static let deleteConfirmation = L10n.string("tasks.delete_confirmation")
        static let deleteMessage = L10n.string("tasks.delete_message")
        static let taskTitle = L10n.string("tasks.task_title")
        static let taskTitlePlaceholder = L10n.string("tasks.task_title_placeholder")
        static let notes = L10n.string("tasks.notes")
        static let notesPlaceholder = L10n.string("tasks.notes_placeholder")
        static let dueDate = L10n.string("tasks.due_date")
        static let selectDateTime = L10n.string("tasks.select_date_time")
        static let priority = L10n.string("tasks.priority")
        static let reminderWillBeCreated = L10n.string("tasks.reminder_will_be_created")
        static let complete = L10n.string("tasks.complete")
        static let resume = L10n.string("tasks.resume")
        static let remaining = L10n.string("tasks.remaining")
        static let completed = L10n.string("tasks.completed")
        static let upcoming = L10n.string("tasks.upcoming")
    }
    
    // MARK: - Today View
    struct Today {
        static let hello = L10n.string("today.hello")
        static let todaysTasks = L10n.string("today.todays_tasks")
        static let completedToday = L10n.string("today.completed_today")
        static let hide = L10n.string("today.hide")
        static let showAll = L10n.string("today.show_all")
        static let showAllWithCount = L10n.string("today.show_all_with_count")
        static let emptyStateTitle = L10n.string("today.empty_state_title")
        static let emptyStateMessage = L10n.string("today.empty_state_message")
        
        // Greetings
        static let goodMorning = L10n.string("today.good_morning")
        static let goodAfternoon = L10n.string("today.good_afternoon")
        static let goodEvening = L10n.string("today.good_evening")
        static let goodNight = L10n.string("today.good_night")
        
        // Motivational quotes
        static let quote1 = L10n.string("today.quote_1")
        static let quote2 = L10n.string("today.quote_2")
        static let quote3 = L10n.string("today.quote_3")
        static let quote4 = L10n.string("today.quote_4")
        static let quote5 = L10n.string("today.quote_5")
    }
    
    // MARK: - Priority
    struct Priority {
        static let none = L10n.string("priority.none")
        static let low = L10n.string("priority.low")
        static let medium = L10n.string("priority.medium")
        static let high = L10n.string("priority.high")
    }

    struct AIActionText {
        static let createTaskTitle = L10n.string("ai.action.create_task.title")
        static let updateTaskTitle = L10n.string("ai.action.update_task.title")
        static let deleteTaskTitle = L10n.string("ai.action.delete_task.title")
        static let createEventTitle = L10n.string("ai.action.create_event.title")
        static let updateEventTitle = L10n.string("ai.action.update_event.title")
        static let deleteEventTitle = L10n.string("ai.action.delete_event.title")
        static let scheduleTaskTitle = L10n.string("ai.action.schedule_task.title")
        static let clarificationTitle = L10n.string("ai.action.clarification.title")
        static let answerTitle = L10n.string("ai.action.answer.title")
    }

    struct AIToast {
        static func taskCreated(_ title: String) -> String {
            String(format: L10n.string("ai.toast.task_created"), title)
        }

        static func eventCreated(_ title: String, time: String?) -> String {
            if let time {
                return String(format: L10n.string("ai.toast.event_created_with_time"), title, time)
            }
            return String(format: L10n.string("ai.toast.event_created"), title)
        }

        static let slots = L10n.string("ai.toast.slots")
        static let `default` = L10n.string("ai.toast.default")
    }

    struct AIInline {
        static let title = L10n.string("ai.inline.title")
        static let titlePlaceholder = L10n.string("ai.inline.title_placeholder")
        static let notes = L10n.string("ai.inline.notes")
        static let notesPlaceholder = L10n.string("ai.inline.notes_placeholder")
        static let priority = L10n.string("ai.inline.priority")
        static let start = L10n.string("ai.inline.start")
        static let end = L10n.string("ai.inline.end")
        static let addStart = L10n.string("ai.inline.add_start")
        static let addEnd = L10n.string("ai.inline.add_end")
        static let allDay = L10n.string("ai.inline.all_day")
        static let removeSchedule = L10n.string("ai.inline.remove_schedule")
    }
}

// MARK: - String Extension for Localization
extension String {
    var localized: String {
        return L10n.string(self)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: L10n.string(self), arguments: arguments)
    }
}
