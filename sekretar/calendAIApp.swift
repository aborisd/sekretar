import SwiftUI
import CoreData
import UserNotifications
import BackgroundTasks

@main
struct SekretarApp: App {
    let persistence = PersistenceController.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            AppEntryPoint()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .onAppear {
                    // Ensure we have a default model folder structure ready for MLC runtime
                    ModelManager.shared.ensureDefaultModelIfMissing()
                    requestNotificationPermissions()
                    // Clean up any empty draft tasks created by previous bug
                    Task { await MaintenanceService.purgeEmptyDraftTasks(in: persistence.container.viewContext) }

                    // Initialize sync service
                    initializeSync()
                }
        }
    }

    private func requestNotificationPermissions() {
        Task {
            _ = await NotificationService.requestAuthorization()
        }
    }

    private func initializeSync() {
        Task {
            // Schedule background sync
            await SyncService.shared.scheduleBackgroundSync()

            // Perform initial sync if authenticated
            if await AuthManager.shared.isAuthenticated() {
                print("🔄 [App] Performing initial sync...")
                do {
                    _ = try await SyncService.shared.sync(force: false)
                } catch {
                    print("⚠️ [App] Initial sync failed: \(error)")
                }
            }
        }
    }
}

// MARK: - AppDelegate for background tasks
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register background tasks
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.sekretar.backgroundSync",
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }

        print("✅ [App] Background tasks registered")
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background sync when app goes to background
        Task {
            await SyncService.shared.scheduleBackgroundSync()
        }
    }

    private func handleBackgroundSync(task: BGAppRefreshTask) {
        print("🌙 [App] Background sync triggered")

        Task {
            do {
                _ = try await SyncService.shared.sync(force: false)
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ [App] Background sync failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            print("⏰ [App] Background sync expired")
        }
    }
}
