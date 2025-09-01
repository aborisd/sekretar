import Foundation
import SwiftUI
import CoreData

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var notificationsEnabled: Bool = true
    @Published var locationPermissionGranted: Bool = false
    @Published var calendarPermissionGranted: Bool = false
    @Published var selectedTheme: AppTheme = .system
    @Published var selectedLanguage: AppLanguage = .russian
    @Published var workingHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 9))!
    @Published var workingHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 18))!
    @Published var selectedAIProvider: AIProvider = .openAI
    @Published var debugModeEnabled: Bool = false
    
    private let context: NSManagedObjectContext
    private let defaults = UserDefaults.standard
    
    enum AppTheme: String, CaseIterable, Identifiable {
        case light = "light"
        case dark = "dark"
        case system = "system"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .light: return "Светлая"
            case .dark: return "Темная"
            case .system: return "Системная"
            }
        }
    }
    
    enum AppLanguage: String, CaseIterable, Identifiable {
        case russian = "ru"
        case english = "en"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .russian: return "Русский"
            case .english: return "English"
            }
        }
    }
    
    enum AIProvider: String, CaseIterable, Identifiable {
        case openAI = "openai"
        case local = "local"
        case disabled = "disabled"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .openAI: return "OpenAI"
            case .local: return "Локальный ИИ"
            case .disabled: return "Отключен"
            }
        }
    }
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        loadSettings()
    }
    
    private func loadSettings() {
        notificationsEnabled = defaults.bool(forKey: "notifications_enabled") 
        selectedTheme = AppTheme(rawValue: defaults.string(forKey: "app_theme") ?? "system") ?? .system
        selectedLanguage = AppLanguage(rawValue: defaults.string(forKey: "app_language") ?? "ru") ?? .russian
        selectedAIProvider = AIProvider(rawValue: defaults.string(forKey: "ai_provider") ?? "openai") ?? .openAI
        debugModeEnabled = defaults.bool(forKey: "debug_mode_enabled")
        
        if let workStartData = defaults.object(forKey: "work_hours_start") as? Date {
            workingHoursStart = workStartData
        }
        if let workEndData = defaults.object(forKey: "work_hours_end") as? Date {
            workingHoursEnd = workEndData
        }
    }
    
    func saveSettings() {
        defaults.set(notificationsEnabled, forKey: "notifications_enabled")
        defaults.set(selectedTheme.rawValue, forKey: "app_theme")
        defaults.set(selectedLanguage.rawValue, forKey: "app_language")
        defaults.set(selectedAIProvider.rawValue, forKey: "ai_provider")
        defaults.set(debugModeEnabled, forKey: "debug_mode_enabled")
        defaults.set(workingHoursStart, forKey: "work_hours_start")
        defaults.set(workingHoursEnd, forKey: "work_hours_end")
        
        AnalyticsService.shared.track(.settingsChanged)
    }
    
    func requestNotificationPermission() async {
        let granted = await NotificationService.requestAuthorization()
        notificationsEnabled = granted
        saveSettings()
    }
    
    func requestLocationPermission() async {
        let granted = await SmartRemindersService.shared.requestLocationPermission()
        locationPermissionGranted = granted
        saveSettings()
    }
    
    func requestCalendarPermission() async {
        let eventKitService = EventKitService(context: context)
        let granted = await eventKitService.requestAccess()
        calendarPermissionGranted = granted
        saveSettings()
    }
    
    func resetAllSettings() {
        let keys = [
            "notifications_enabled", "app_theme", "app_language", 
            "ai_provider", "debug_mode_enabled", "work_hours_start", "work_hours_end"
        ]
        
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        
        loadSettings()
        AnalyticsService.shared.track(.settingsReset)
    }
    
    func generateTestData() {
        // Generate sample test data for demonstration
        print("🧪 Generating test data...")
        
        // This method can be used to populate the app with sample tasks and events
        // for testing purposes
    }
    
    func exportUserData() -> URL? {
        // Export user data for backup
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportURL = documentsPath.appendingPathComponent("calendai_backup_\(Date().timeIntervalSince1970).json")
        
        do {
            let backup = createBackupData()
            let data = try JSONSerialization.data(withJSONObject: backup, options: .prettyPrinted)
            try data.write(to: exportURL)
            return exportURL
        } catch {
            print("❌ Export failed: \(error)")
            return nil
        }
    }
    
    private func createBackupData() -> [String: Any] {
        return [
            "settings": [
                "notifications_enabled": notificationsEnabled,
                "app_theme": selectedTheme.rawValue,
                "app_language": selectedLanguage.rawValue,
                "ai_provider": selectedAIProvider.rawValue,
                "debug_mode_enabled": debugModeEnabled
            ],
            "export_date": Date().timeIntervalSince1970,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "1.0"
        ]
    }
}

// Analytics extension
extension AnalyticsEvent {
    static let settingsChanged = AnalyticsEvent(rawValue: "settings_changed")!
    static let settingsReset = AnalyticsEvent(rawValue: "settings_reset")!
}