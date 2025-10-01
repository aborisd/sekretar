import Foundation
import os.log
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Crash Reporting Service
/// Crash monitoring для TestFlight (BRD строки 100, 477)
@MainActor
final class CrashReportingService: ObservableObject {
    static let shared = CrashReportingService()

    @Published var recentCrashes: [CrashReport] = []
    @Published var isEnabled = true

    private let logger = Logger(subsystem: "com.sekretar", category: "CrashReporting")
    private let crashLogDirectory: URL

    private init() {
        // Create crash logs directory
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        crashLogDirectory = documentsDir.appendingPathComponent("CrashLogs", isDirectory: true)

        try? FileManager.default.createDirectory(at: crashLogDirectory, withIntermediateDirectories: true)

        setupCrashHandling()
        loadRecentCrashes()
    }

    // MARK: - Setup

    private func setupCrashHandling() {
        // Set up NSSetUncaughtExceptionHandler
        NSSetUncaughtExceptionHandler { exception in
            Task { @MainActor in
                CrashReportingService.shared.handleException(exception)
            }
        }

        // Set up signal handlers for fatal signals
        signal(SIGABRT) { signal in
            CrashReportingService.handleSignal(signal, name: "SIGABRT")
        }
        signal(SIGILL) { signal in
            CrashReportingService.handleSignal(signal, name: "SIGILL")
        }
        signal(SIGSEGV) { signal in
            CrashReportingService.handleSignal(signal, name: "SIGSEGV")
        }
        signal(SIGFPE) { signal in
            CrashReportingService.handleSignal(signal, name: "SIGFPE")
        }
        signal(SIGBUS) { signal in
            CrashReportingService.handleSignal(signal, name: "SIGBUS")
        }
        signal(SIGPIPE) { signal in
            CrashReportingService.handleSignal(signal, name: "SIGPIPE")
        }

        logger.info("✅ Crash reporting initialized")
    }

    // MARK: - Crash Handling

    private func handleException(_ exception: NSException) {
        let report = CrashReport(
            timestamp: Date(),
            type: .exception,
            name: exception.name.rawValue,
            reason: exception.reason ?? "Unknown",
            stackTrace: exception.callStackSymbols.joined(separator: "\n"),
            appVersion: appVersion(),
            osVersion: osVersion(),
            deviceModel: deviceModel()
        )

        saveCrashReport(report)
        logger.error("💥 Exception: \(exception.name.rawValue) - \(exception.reason ?? "")")
    }

    private static func handleSignal(_ signal: Int32, name: String) {
        let report = CrashReport(
            timestamp: Date(),
            type: .signal,
            name: name,
            reason: "Signal \(signal) received",
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            appVersion: CrashReportingService.shared.appVersion(),
            osVersion: CrashReportingService.shared.osVersion(),
            deviceModel: CrashReportingService.shared.deviceModel()
        )

        Task { @MainActor in
            CrashReportingService.shared.saveCrashReport(report)
        }

        // Re-raise signal to allow system handling
        Darwin.signal(signal, SIG_DFL)
        raise(signal)
    }

    // MARK: - Manual Error Reporting

    func reportError(_ error: Error, context: String = "", severity: ErrorSeverity = .error) {
        let report = CrashReport(
            timestamp: Date(),
            type: .error,
            name: "\(type(of: error))",
            reason: error.localizedDescription,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            appVersion: appVersion(),
            osVersion: osVersion(),
            deviceModel: deviceModel(),
            context: context,
            severity: severity
        )

        saveCrashReport(report)

        // Log to analytics
        AnalyticsService.shared.track(.errorReported, properties: [
            "error_type": "\(type(of: error))",
            "context": context,
            "severity": severity.rawValue
        ])

        logger.error("❌ Error reported: \(error.localizedDescription) [Context: \(context)]")
    }

    // MARK: - Persistence

    private func saveCrashReport(_ report: CrashReport) {
        guard isEnabled else { return }

        recentCrashes.insert(report, at: 0)

        // Keep only last 50 crashes in memory
        if recentCrashes.count > 50 {
            recentCrashes = Array(recentCrashes.prefix(50))
        }

        // Save to disk
        let filename = "crash_\(report.timestamp.timeIntervalSince1970).json"
        let fileURL = crashLogDirectory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let data = try? encoder.encode(report) {
            try? data.write(to: fileURL)
            logger.info("💾 Crash report saved: \(filename)")
        }
    }

    private func loadRecentCrashes() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: crashLogDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let decoder = JSONDecoder()

        let sortedFiles = files
            .filter { $0.pathExtension == "json" }
            .sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }

        let crashes = Array(sortedFiles.prefix(50)).compactMap { fileURL -> CrashReport? in
            guard let data = try? Data(contentsOf: fileURL),
                  let report = try? decoder.decode(CrashReport.self, from: data) else {
                return nil
            }
            return report
        }

        self.recentCrashes = crashes

        logger.info("📂 Loaded \(self.recentCrashes.count) crash reports")
    }

    // MARK: - Export & Cleanup

    func exportCrashLogs() -> URL? {
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("crash_logs_\(Date().timeIntervalSince1970).json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let data = try? encoder.encode(recentCrashes) {
            try? data.write(to: exportURL)
            logger.info("📤 Crash logs exported to: \(exportURL)")
            return exportURL
        }

        return nil
    }

    func clearCrashLogs() {
        // Remove all crash log files
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: crashLogDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files {
            try? FileManager.default.removeItem(at: file)
        }

        recentCrashes.removeAll()
        logger.info("🗑️ Crash logs cleared")
    }

    // MARK: - System Info

    private func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    private func osVersion() -> String {
        #if os(iOS)
        return "iOS \(UIDevice.current.systemVersion)"
        #elseif os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #else
        return "Unknown OS"
        #endif
    }

    private func deviceModel() -> String {
        #if os(iOS)
        return UIDevice.current.model
        #elseif os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
        #else
        return "Unknown Device"
        #endif
    }
}

// MARK: - Models

struct CrashReport: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let type: CrashType
    let name: String
    let reason: String
    let stackTrace: String
    let appVersion: String
    let osVersion: String
    let deviceModel: String
    let context: String?
    let severity: ErrorSeverity

    init(
        timestamp: Date,
        type: CrashType,
        name: String,
        reason: String,
        stackTrace: String,
        appVersion: String,
        osVersion: String,
        deviceModel: String,
        context: String? = nil,
        severity: ErrorSeverity = .error
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.type = type
        self.name = name
        self.reason = reason
        self.stackTrace = stackTrace
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.context = context
        self.severity = severity
    }

    var displayTitle: String {
        "\(type.icon) \(name)"
    }

    var displayTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

enum CrashType: String, Codable {
    case exception
    case signal
    case error

    var icon: String {
        switch self {
        case .exception: return "💥"
        case .signal: return "⚡️"
        case .error: return "❌"
        }
    }
}

enum ErrorSeverity: String, Codable {
    case debug
    case info
    case warning
    case error
    case fatal

    var displayName: String {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .fatal: return "Fatal"
        }
    }
}

// MARK: - Analytics Extensions
extension AnalyticsEvent {
    static let errorReported = AnalyticsEvent(rawValue: "error_reported")!
}

// MARK: - Global Error Handler Helper
func reportError(_ error: Error, context: String = "", severity: ErrorSeverity = .error) {
    Task { @MainActor in
        CrashReportingService.shared.reportError(error, context: context, severity: severity)
    }
}
