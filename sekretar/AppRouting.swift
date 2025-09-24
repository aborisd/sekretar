import Foundation
import SwiftUI

enum AppTab: String { case home, calendar, tasks }

extension Notification.Name {
    static let openCalendarOn = Notification.Name("SekretarOpenCalendar")
    static let openTasksOn = Notification.Name("SekretarOpenTasks")
    static let focusCalendarDate = Notification.Name("SekretarFocusCalendarDate")
}

struct OpenLink: Identifiable, Equatable {
    let id = UUID()
    enum Tab { case calendar, tasks }
    let tab: Tab
    let date: Date?
}
