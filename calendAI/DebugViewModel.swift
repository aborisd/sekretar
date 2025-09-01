import Foundation
import SwiftUI

@MainActor
class DebugViewModel: ObservableObject {
    @Published var isDebugModeEnabled: Bool = false
    @Published var logLevel: LogLevel = .info
    @Published var showInternalMetrics: Bool = false
    @Published var mockDataEnabled: Bool = false
    @Published var logs: [String] = []
    
    enum LogLevel: String, CaseIterable {
        case debug = "Debug"
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
    }
    
    init() {
        loadDebugSettings()
    }
    
    private func loadDebugSettings() {
        isDebugModeEnabled = UserDefaults.standard.bool(forKey: "debug_mode_enabled")
        showInternalMetrics = UserDefaults.standard.bool(forKey: "show_internal_metrics")
        mockDataEnabled = UserDefaults.standard.bool(forKey: "mock_data_enabled")
        
        if let logLevelString = UserDefaults.standard.string(forKey: "log_level"),
           let level = LogLevel(rawValue: logLevelString) {
            logLevel = level
        }
    }
    
    func saveDebugSettings() {
        UserDefaults.standard.set(isDebugModeEnabled, forKey: "debug_mode_enabled")
        UserDefaults.standard.set(showInternalMetrics, forKey: "show_internal_metrics")
        UserDefaults.standard.set(mockDataEnabled, forKey: "mock_data_enabled")
        UserDefaults.standard.set(logLevel.rawValue, forKey: "log_level")
    }
    
    func resetAllDebugSettings() {
        isDebugModeEnabled = false
        showInternalMetrics = false
        mockDataEnabled = false
        logLevel = .info
        saveDebugSettings()
    }
    
    func exportDebugLogs() -> String {
        return """
        Debug Settings Export
        ====================
        Debug Mode: \(isDebugModeEnabled)
        Log Level: \(logLevel.rawValue)
        Internal Metrics: \(showInternalMetrics)
        Mock Data: \(mockDataEnabled)
        Export Date: \(Date())
        """
    }
}