import Foundation
import SwiftUI

protocol FeatureFlagsProtocol {
    func isEnabled(_ feature: FeatureFlag) -> Bool
    func enable(_ feature: FeatureFlag)
    func disable(_ feature: FeatureFlag)
    func setRemoteFlags(_ flags: [String: Bool])
}

enum FeatureFlag: String, CaseIterable {
    // Core Features
    case aiFeatures = "ai_features"
    case eventKitIntegration = "eventkit_integration"
    case voiceInput = "voice_input"
    case smartReminders = "smart_reminders"
    
    // UI Features
    case widgets = "widgets"
    case darkMode = "dark_mode"
    case tabletUI = "tablet_ui"
    case compactView = "compact_view"
    
    // Advanced Features
    case autoScheduling = "auto_scheduling"
    case conflictDetection = "conflict_detection"
    case projectsOrganization = "projects_organization"
    case advancedAnalytics = "advanced_analytics"
    
    // Experimental
    case betaChat = "beta_chat"
    case mlPrioritization = "ml_prioritization"
    case calendarSharing = "calendar_sharing"
    
    // Debug
    case debugMode = "debug_mode"
    case stressTest = "stress_test"
    case performanceMetrics = "performance_metrics"
    case useInMemoryStore = "use_in_memory_store"
    
    var defaultValue: Bool {
        switch self {
        // Enabled by default in M0
        case .aiFeatures, .eventKitIntegration, .smartReminders, .darkMode:
            return true
        
        // Enabled in M1
        case .widgets, .conflictDetection:
            return false
        
        // Enabled in M2
        case .autoScheduling, .voiceInput, .projectsOrganization:
            return false
        
        // Experimental - off by default
        case .betaChat, .mlPrioritization, .calendarSharing, .advancedAnalytics:
            return false
        
        // UI improvements
        case .compactView, .tabletUI:
            return false
        
        // Debug features
        case .debugMode, .useInMemoryStore:
            #if DEBUG
            return true
            #else
            return false
            #endif
        case .stressTest, .performanceMetrics:
            return false
        }
    }
    
    var description: String {
        switch self {
        case .aiFeatures: return "AI-powered suggestions and automation"
        case .eventKitIntegration: return "System calendar integration"
        case .voiceInput: return "Speech-to-text for task creation"
        case .smartReminders: return "Intelligent notification timing"
        case .widgets: return "Home screen widgets"
        case .darkMode: return "Dark mode support"
        case .tabletUI: return "iPad-optimized interface"
        case .compactView: return "Compact list views"
        case .autoScheduling: return "Automatic task scheduling"
        case .conflictDetection: return "Schedule conflict warnings"
        case .projectsOrganization: return "Project-based task organization"
        case .advancedAnalytics: return "Detailed usage analytics"
        case .betaChat: return "Enhanced AI chat interface"
        case .mlPrioritization: return "Machine learning task prioritization"
        case .calendarSharing: return "Calendar sharing and collaboration"
        case .debugMode: return "Developer debug tools"
        case .stressTest: return "Performance stress testing"
        case .performanceMetrics: return "Real-time performance monitoring"
        case .useInMemoryStore: return "Use in-memory Core Data store"
        }
    }
}

final class FeatureFlags: FeatureFlagsProtocol, ObservableObject {
    static let shared = FeatureFlags()
    
    @Published private var localFlags: [String: Bool] = [:]
    @Published private var remoteFlags: [String: Bool] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let localFlagsKey = "local_feature_flags"
    private let remoteFlagsKey = "remote_feature_flags"
    
    private init() {
        loadFlags()
    }
    
    func isEnabled(_ feature: FeatureFlag) -> Bool {
        // Priority: Remote > Local > Default
        if let remoteValue = remoteFlags[feature.rawValue] {
            return remoteValue
        }
        
        if let localValue = localFlags[feature.rawValue] {
            return localValue
        }
        
        return feature.defaultValue
    }
    
    func enable(_ feature: FeatureFlag) {
        localFlags[feature.rawValue] = true
        saveFlags()
        
        AnalyticsService.shared.trackFeatureFlag(feature.rawValue, enabled: true)
    }
    
    func disable(_ feature: FeatureFlag) {
        localFlags[feature.rawValue] = false
        saveFlags()
        
        AnalyticsService.shared.trackFeatureFlag(feature.rawValue, enabled: false)
    }
    
    func setRemoteFlags(_ flags: [String: Bool]) {
        remoteFlags = flags
        saveRemoteFlags()
        objectWillChange.send()
    }
    
    func getAllFlags() -> [FeatureFlag: Bool] {
        var result: [FeatureFlag: Bool] = [:]
        for flag in FeatureFlag.allCases {
            result[flag] = isEnabled(flag)
        }
        return result
    }
    
    private func loadFlags() {
        if let data = userDefaults.data(forKey: localFlagsKey),
           let flags = try? JSONDecoder().decode([String: Bool].self, from: data) {
            localFlags = flags
        }
        
        if let data = userDefaults.data(forKey: remoteFlagsKey),
           let flags = try? JSONDecoder().decode([String: Bool].self, from: data) {
            remoteFlags = flags
        }
    }
    
    private func saveFlags() {
        if let data = try? JSONEncoder().encode(localFlags) {
            userDefaults.set(data, forKey: localFlagsKey)
        }
    }
    
    private func saveRemoteFlags() {
        if let data = try? JSONEncoder().encode(remoteFlags) {
            userDefaults.set(data, forKey: remoteFlagsKey)
        }
    }
}

// MARK: - Convenience Extensions
extension FeatureFlags {
    // Quick access to commonly used flags
    var aiEnabled: Bool { isEnabled(.aiFeatures) }
    var eventKitEnabled: Bool { isEnabled(.eventKitIntegration) }
    var widgetsEnabled: Bool { isEnabled(.widgets) }
    var debugModeEnabled: Bool { isEnabled(.debugMode) }
    var voiceInputEnabled: Bool { isEnabled(.voiceInput) }
    var autoSchedulingEnabled: Bool { isEnabled(.autoScheduling) }
    var useInMemoryStoreForDev: Bool { isEnabled(.useInMemoryStore) }
}

// MARK: - SwiftUI Environment
struct FeatureFlagsKey: EnvironmentKey {
    static let defaultValue: FeatureFlags = FeatureFlags.shared
}

extension EnvironmentValues {
    var featureFlags: FeatureFlags {
        get { self[FeatureFlagsKey.self] }
        set { self[FeatureFlagsKey.self] = newValue }
    }
}
