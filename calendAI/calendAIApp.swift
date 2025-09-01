import SwiftUI
import UserNotifications

@main
struct calendAIApp: App {
    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            DemoContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .onAppear {
                    requestNotificationPermissions()
                }
        }
    }
    
    private func requestNotificationPermissions() {
        Task {
            _ = await NotificationService.requestAuthorization()
        }
    }
}