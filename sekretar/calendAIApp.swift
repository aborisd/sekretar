import SwiftUI
import CoreData
import UserNotifications

@main
struct SekretarApp: App {
    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            DemoContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .onAppear {
                    // Ensure we have a default model folder structure ready for MLC runtime
                    ModelManager.shared.ensureDefaultModelIfMissing()
                    requestNotificationPermissions()
                    // Clean up any empty draft tasks created by previous bug
                    Task { await MaintenanceService.purgeEmptyDraftTasks(in: persistence.container.viewContext) }
                }
        }
    }
    
    private func requestNotificationPermissions() {
        Task {
            _ = await NotificationService.requestAuthorization()
        }
    }
}
