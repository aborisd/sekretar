import Foundation
import os.log

protocol AnalyticsServiceProtocol {
    func track(_ event: AnalyticsEvent)
    func track(_ event: AnalyticsEvent, properties: [String: Any])
    func setUserProperty(_ key: String, value: Any)
    func flush()
}

enum AnalyticsEvent: String, CaseIterable {
    case appOpened = "app_opened"
    case taskCreated = "task_created"
    case taskUpdated = "task_updated"
    case taskCompleted = "task_completed"
    case taskDeleted = "task_deleted"
    case eventCreated = "event_created"
    case aiPromptSubmitted = "ai_prompt_submitted"
    case aiSuggestionAccepted = "ai_suggestion_accepted"
    case aiSuggestionRejected = "ai_suggestion_rejected"
    case reminderScheduled = "reminder_scheduled"
    case reminderMissed = "reminder_missed"
    case reminderSnoozed = "reminder_snoozed"
    case calendarImported = "calendar_imported"
    case settingsOpened = "settings_opened"
    case onboardingCompleted = "onboarding_completed"
}

final class AnalyticsService: AnalyticsServiceProtocol {
    static let shared = AnalyticsService()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "sekretar", category: "Analytics")
    private var userProperties: [String: Any] = [:]
    private var eventQueue: [(event: AnalyticsEvent, properties: [String: Any], timestamp: Date)] = []
    private let maxQueueSize = 100
    
    private init() {}
    
    func track(_ event: AnalyticsEvent) {
        track(event, properties: [:])
    }
    
    func track(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        let timestamp = Date()
        
        // Log locally for debugging
        logger.info("📊 Analytics: \(event.rawValue) \(properties)")
        
        // Add to queue
        eventQueue.append((event: event, properties: properties, timestamp: timestamp))
        
        // Auto-flush if queue is full
        if eventQueue.count >= maxQueueSize {
            flush()
        }
        
        // Log funnel events
        logFunnelEvent(event, properties: properties)
    }
    
    func setUserProperty(_ key: String, value: Any) {
        userProperties[key] = value
        logger.info("👤 User Property: \(key) = \(String(describing: value))")
    }
    
    func flush() {
        guard !eventQueue.isEmpty else { return }
        
        logger.info("🚀 Flushing \(self.eventQueue.count) analytics events")
        
        // In production, send to analytics service (TelemetryDeck, etc.)
        // For now, just log and clear
        for eventData in eventQueue {
            logger.info("📤 Event: \(eventData.event.rawValue) at \(eventData.timestamp)")
        }
        
        eventQueue.removeAll()
    }
    
    private func logFunnelEvent(_ event: AnalyticsEvent, properties: [String: Any]) {
        switch event {
        case .appOpened:
            logger.info("🔄 Funnel: User opened app")
        case .aiPromptSubmitted:
            logger.info("🔄 Funnel: User submitted AI prompt")
        case .aiSuggestionAccepted:
            logger.info("🔄 Funnel: User accepted AI suggestion")
        case .taskCreated:
            let via = properties["via"] as? String ?? "manual"
            logger.info("🔄 Funnel: Task created via \(via)")
        case .eventCreated:
            let hasConflict = properties["has_conflict"] as? Bool ?? false
            logger.info("🔄 Funnel: Event created (conflict: \(hasConflict))")
        default:
            break
        }
    }
    
    // MARK: - Convenience Methods
    
    func trackTaskCreated(via: String, priority: Int16) {
        track(.taskCreated, properties: [
            "via": via,
            "priority": priority
        ])
    }
    
    func trackTaskCompleted(completionTime: TimeInterval, priority: Int16) {
        track(.taskCompleted, properties: [
            "completion_time": completionTime,
            "priority": priority
        ])
    }
    
    func trackAIPrompt(type: String, confidence: Double, accepted: Bool) {
        track(.aiPromptSubmitted, properties: [
            "type": type,
            "confidence": confidence
        ])
        
        if accepted {
            track(.aiSuggestionAccepted, properties: [
                "type": type,
                "confidence": confidence
            ])
        } else {
            track(.aiSuggestionRejected, properties: [
                "type": type,
                "confidence": confidence
            ])
        }
    }
    
    func trackReminderInteraction(action: String, taskPriority: Int16) {
        let eventType: AnalyticsEvent = {
            switch action {
            case "missed": return .reminderMissed
            case "snoozed": return .reminderSnoozed
            default: return .reminderScheduled
            }
        }()
        
        track(eventType, properties: [
            "task_priority": taskPriority,
            "action": action
        ])
    }
}

// MARK: - Feature Flags Integration
extension AnalyticsService {
    func trackFeatureFlag(_ flag: String, enabled: Bool) {
        track(.settingsOpened, properties: [
            "feature_flag": flag,
            "enabled": enabled
        ])
    }
}
