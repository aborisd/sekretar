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
                    // Ensure we have a default model folder structure ready for MLC runtime
                    ModelManager.shared.ensureDefaultModelIfMissing()
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
