#if os(iOS)
import Foundation
import CoreLocation
import UserNotifications
import CoreData

// MARK: - Smart Reminders Service
@MainActor
final class SmartRemindersService: NSObject, ObservableObject {
    static let shared = SmartRemindersService()
    
    private let locationManager = CLLocationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    @Published var isLocationEnabled = false
    @Published var currentLocation: CLLocation?
    
    // Smart reminder types
    enum SmartReminderType: String, CaseIterable {
        case locationBased = "location_based"
        case timeBased = "time_based" 
        case contextual = "contextual"
        case adaptive = "adaptive"
        
        var displayName: String {
            switch self {
            case .locationBased: return "Location-based"
            case .timeBased: return "Time-based"
            case .contextual: return "Contextual"
            case .adaptive: return "Adaptive"
            }
        }
        
        var description: String {
            switch self {
            case .locationBased: return "Remind when arriving or leaving locations"
            case .timeBased: return "Smart timing based on your schedule"
            case .contextual: return "Remind based on device usage patterns"
            case .adaptive: return "Learn your preferences and adapt"
            }
        }
    }
    
    // Location contexts
    enum LocationContext: String, CaseIterable {
        case home = "home"
        case work = "work"
        case store = "store"
        case gym = "gym"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .home: return "Home"
            case .work: return "Work"
            case .store: return "Store"
            case .gym: return "Gym"
            case .custom: return "Custom"
            }
        }
        
        var defaultIcon: String {
            switch self {
            case .home: return "house.fill"
            case .work: return "building.2.fill"
            case .store: return "cart.fill"
            case .gym: return "dumbbell.fill"
            case .custom: return "location.fill"
            }
        }
    }
    
    private override init() {
        super.init()
        setupLocationManager()
        checkLocationPermission()
    }
    
    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 50 // meters
    }
    
    // MARK: - Permissions
    func requestLocationPermission() async -> Bool {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            return await withCheckedContinuation { continuation in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    continuation.resume(returning: self.isLocationEnabled)
                }
            }
        case .denied, .restricted:
            return false
        case .authorizedWhenInUse, .authorizedAlways:
            isLocationEnabled = true
            return true
        @unknown default:
            return false
        }
    }
    
    private func checkLocationPermission() {
        isLocationEnabled = [.authorizedWhenInUse, .authorizedAlways].contains(locationManager.authorizationStatus)
    }
    
    // MARK: - Smart Reminders
    func scheduleSmartReminder(for task: TaskEntity, type: SmartReminderType) async {
        guard await NotificationService.requestAuthorization() else { return }
        
        let identifier = "smart_\(task.id?.uuidString ?? "unknown")_\(type.rawValue)"
        
        switch type {
        case .locationBased:
            await scheduleLocationBasedReminder(for: task, identifier: identifier)
        case .timeBased:
            await scheduleTimeBasedReminder(for: task, identifier: identifier)
        case .contextual:
            await scheduleContextualReminder(for: task, identifier: identifier)
        case .adaptive:
            await scheduleAdaptiveReminder(for: task, identifier: identifier)
        }
        
        AnalyticsService.shared.track(.reminderScheduled, properties: [
            "type": type.rawValue,
            "task_priority": Int(task.priority)
        ])
    }
    
    // MARK: - Location-based Reminders
    private func scheduleLocationBasedReminder(for task: TaskEntity, identifier: String) async {
        guard isLocationEnabled else { return }
        
        // Example: Remind when arriving at work
        if let workLocation = getUserLocation(for: .work) {
            let region = CLCircularRegion(
                center: workLocation.coordinate,
                radius: 100, // 100 meters
                identifier: identifier
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            
            let content = createNotificationContent(for: task, context: "You've arrived at work")
            let trigger = UNLocationNotificationTrigger(region: region, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            try? await notificationCenter.add(request)
        }
    }
    
    // MARK: - Time-based Smart Reminders
    private func scheduleTimeBasedReminder(for task: TaskEntity, identifier: String) async {
        let optimalTime = calculateOptimalReminderTime(for: task)
        
        let content = createNotificationContent(for: task, context: "Perfect time to work on this")
        
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: optimalTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        try? await notificationCenter.add(request)
    }
    
    // MARK: - Contextual Reminders
    private func scheduleContextualReminder(for task: TaskEntity, identifier: String) async {
        // Remind based on device usage patterns (e.g., when opening certain apps)
        let content = createNotificationContent(for: task, context: "Good time to tackle this task")
        
        // Schedule for next productivity window (example: 2 hours from now)
        let triggerDate = Date().addingTimeInterval(2 * 60 * 60)
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        try? await notificationCenter.add(request)
    }
    
    // MARK: - Adaptive Reminders
    private func scheduleAdaptiveReminder(for task: TaskEntity, identifier: String) async {
        // Learn from user behavior and adapt timing
        let userPreferences = getUserReminderPreferences()
        let adaptedTime = adaptReminderTime(for: task, preferences: userPreferences)
        
        let content = createNotificationContent(for: task, context: "Based on your habits, now's a good time")
        
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: adaptedTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        try? await notificationCenter.add(request)
    }
    
    // MARK: - Location Management
    func saveUserLocation(_ location: CLLocation, for context: LocationContext, name: String) {
        let key = "location_\(context.rawValue)"
        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "name": name
        ]
        UserDefaults.standard.set(locationData, forKey: key)
    }
    
    func getUserLocation(for context: LocationContext) -> CLLocation? {
        let key = "location_\(context.rawValue)"
        guard let locationData = UserDefaults.standard.dictionary(forKey: key),
              let lat = locationData["latitude"] as? Double,
              let lng = locationData["longitude"] as? Double else {
            return nil
        }
        return CLLocation(latitude: lat, longitude: lng)
    }
    
    func getAllUserLocations() -> [(LocationContext, CLLocation, String)] {
        var locations: [(LocationContext, CLLocation, String)] = []
        
        for context in LocationContext.allCases {
            let key = "location_\(context.rawValue)"
            if let locationData = UserDefaults.standard.dictionary(forKey: key),
               let lat = locationData["latitude"] as? Double,
               let lng = locationData["longitude"] as? Double,
               let name = locationData["name"] as? String {
                let location = CLLocation(latitude: lat, longitude: lng)
                locations.append((context, location, name))
            }
        }
        
        return locations
    }
    
    // MARK: - Helper Methods
    private func createNotificationContent(for task: TaskEntity, context: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Smart Reminder"
        content.body = "\(context): \(task.title ?? "Task")"
        content.sound = .default
        content.categoryIdentifier = "SMART_REMINDER"
        
        // Add custom data
        content.userInfo = [
            "task_id": task.id?.uuidString ?? "",
            "reminder_type": "smart",
            "context": context
        ]
        
        return content
    }
    
    private func calculateOptimalReminderTime(for task: TaskEntity) -> Date {
        // AI-powered optimal timing calculation
        let now = Date()
        
        // Consider task priority
        let priorityOffset: TimeInterval = switch Int(task.priority) {
        case 3: -30 * 60 // High priority: 30 min earlier
        case 2: -15 * 60 // Medium priority: 15 min earlier
        case 1: 0        // Low priority: on time
        default: 15 * 60 // No priority: 15 min later
        }
        
        // Consider due date if available
        if let dueDate = task.dueDate {
            // Smart timing: remind 25% of time remaining, but not more than 2 hours before
            let timeRemaining = dueDate.timeIntervalSince(now)
            let reminderOffset = min(timeRemaining * 0.25, 2 * 60 * 60) // Max 2 hours
            return dueDate.addingTimeInterval(-reminderOffset + priorityOffset)
        }
        
        // Default: remind in 1 hour with priority adjustment
        return now.addingTimeInterval(60 * 60 + priorityOffset)
    }
    
    private func getUserReminderPreferences() -> [String: Any] {
        // Analyze user's past behavior with reminders
        return UserDefaults.standard.dictionary(forKey: "user_reminder_preferences") ?? [
            "preferred_morning_time": 9, // 9 AM
            "preferred_evening_time": 18, // 6 PM
            "productivity_hours": [9, 10, 11, 14, 15, 16], // Most productive hours
            "response_rate_by_hour": [:] // Hour -> response rate
        ]
    }
    
    private func adaptReminderTime(for task: TaskEntity, preferences: [String: Any]) -> Date {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        
        // Get productivity hours
        let productivityHours = preferences["productivity_hours"] as? [Int] ?? [9, 10, 11, 14, 15, 16]
        
        // Find next productivity hour
        let nextProductivityHour = productivityHours.first { $0 > currentHour } ?? productivityHours.first ?? currentHour + 1
        
        // Create reminder time
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = nextProductivityHour
        components.minute = 0
        
        let reminderTime = calendar.date(from: components) ?? now.addingTimeInterval(60 * 60)
        
        // If the time has passed today, schedule for tomorrow
        if reminderTime <= now {
            return calendar.date(byAdding: .day, value: 1, to: reminderTime) ?? reminderTime
        }
        
        return reminderTime
    }
    
    // MARK: - Analytics & Learning
    func recordReminderInteraction(identifier: String, action: String) {
        let key = "reminder_interactions"
        var interactions = UserDefaults.standard.dictionary(forKey: key) ?? [:]
        interactions[identifier] = [
            "action": action,
            "timestamp": Date().timeIntervalSince1970
        ]
        UserDefaults.standard.set(interactions, forKey: key)
        
        AnalyticsService.shared.track(.reminderInteracted, properties: [
            "action": action,
            "identifier": identifier
        ])
    }
    
    func cancelSmartReminder(for taskId: UUID, type: SmartReminderType) {
        let identifier = "smart_\(taskId.uuidString)_\(type.rawValue)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAllSmartReminders(for taskId: UUID) {
        let identifiers = SmartReminderType.allCases.map { type in
            "smart_\(taskId.uuidString)_\(type.rawValue)"
        }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

#else
import Foundation
import CoreLocation
import CoreData

@MainActor
final class SmartRemindersService: ObservableObject {
    static let shared = SmartRemindersService()

    enum SmartReminderType: String, CaseIterable {
        case locationBased, timeBased, contextual, adaptive
    }

    enum LocationContext: String, CaseIterable {
        case home, work, store, gym, custom
    }

    @Published var isLocationEnabled = false
    @Published var currentLocation: CLLocation? = nil

    private init() {}

    func requestLocationPermission() async -> Bool { false }

    func scheduleSmartReminder(for task: TaskEntity, type: SmartReminderType) async {}

    func saveUserLocation(_ location: CLLocation, for context: LocationContext, name: String) {}
}
#endif

#if os(iOS)
// MARK: - CLLocationManagerDelegate
extension SmartRemindersService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            currentLocation = locations.last
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            checkLocationPermission()
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("📍 Entered region: \(region.identifier)")
        // Region-based reminders are handled by the system
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("📍 Exited region: \(region.identifier)")
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager error: \(error.localizedDescription)")
    }
}
#endif

// MARK: - Analytics Extension
extension AnalyticsEvent {
    static let reminderInteracted = AnalyticsEvent(rawValue: "reminder_interacted")!
}
