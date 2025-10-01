import SwiftUI

// MARK: - TestFlight Debug View
/// Debug панель для TestFlight тестирования (BRD строка 477)
struct TestFlightDebugView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var crashService = CrashReportingService.shared
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @StateObject private var offlineSync = OfflineSyncService.shared

    @State private var showingCrashDetails: CrashReport?
    @State private var showingShareSheet = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                // App Info
                appInfoSection

                // Performance Metrics
                performanceSection

                // Crash Reports
                crashReportsSection

                // Offline Sync Status
                syncStatusSection

                // Debug Actions
                debugActionsSection
            }
            .navigationTitle("TestFlight Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $showingCrashDetails) { crash in
                CrashDetailView(crash: crash)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    #if os(iOS)
                    ShareSheet(items: [url])
                    #endif
                }
            }
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        Section("App Information") {
            InfoRow(label: "Version", value: appVersion)
            InfoRow(label: "Build", value: buildNumber)
            InfoRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
            InfoRow(label: "Device", value: deviceModel)
            InfoRow(label: "OS", value: osVersion)
        }
    }

    // MARK: - Performance Section

    private var performanceSection: some View {
        Section("Performance") {
            HStack {
                Label("FPS", systemImage: "gauge")
                Spacer()
                Text(String(format: "%.1f", performanceMonitor.currentFPS))
                    .foregroundColor(fpsColor(performanceMonitor.currentFPS))
                    .bold()
            }

            HStack {
                Label("Total Metrics", systemImage: "chart.bar")
                Spacer()
                Text("\(performanceMonitor.metrics.count)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("Alerts", systemImage: "exclamationmark.triangle")
                Spacer()
                Text("\(performanceMonitor.alerts.count)")
                    .foregroundColor(performanceMonitor.alerts.isEmpty ? .green : .orange)
            }

            Button {
                let report = performanceMonitor.generateReport()
                print(report)
            } label: {
                Label("Generate Performance Report", systemImage: "doc.text")
            }
        }
    }

    // MARK: - Crash Reports Section

    private var crashReportsSection: some View {
        Section {
            if crashService.recentCrashes.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No crashes reported")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(crashService.recentCrashes.prefix(10)) { crash in
                    Button {
                        showingCrashDetails = crash
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(crash.displayTitle)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(crash.displayTime)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text(crash.reason)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Button {
                    if let url = crashService.exportCrashLogs() {
                        exportURL = url
                        showingShareSheet = true
                    }
                } label: {
                    Label("Export Crash Logs", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    crashService.clearCrashLogs()
                } label: {
                    Label("Clear All Crashes", systemImage: "trash")
                }
            }
        } header: {
            HStack {
                Text("Crash Reports")
                Spacer()
                Text("\(crashService.recentCrashes.count)")
                    .foregroundColor(crashService.recentCrashes.isEmpty ? .green : .red)
            }
        }
    }

    // MARK: - Sync Status Section

    private var syncStatusSection: some View {
        Section("Offline Sync") {
            HStack {
                Label("Network Status", systemImage: offlineSync.isOnline ? "wifi" : "wifi.slash")
                Spacer()
                Text(offlineSync.isOnline ? "Online" : "Offline")
                    .foregroundColor(offlineSync.isOnline ? .green : .orange)
            }

            HStack {
                Label("Pending Operations", systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                Text("\(offlineSync.pendingOperationsCount)")
                    .foregroundColor(offlineSync.pendingOperationsCount > 0 ? .orange : .green)
            }

            if let lastSync = offlineSync.lastSyncDate {
                HStack {
                    Label("Last Sync", systemImage: "clock")
                    Spacer()
                    Text(lastSync, style: .relative)
                        .foregroundColor(.secondary)
                }
            }

            if offlineSync.pendingOperationsCount > 0 {
                Button {
                    Task {
                        await offlineSync.syncPendingOperations()
                    }
                } label: {
                    Label("Force Sync Now", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    // MARK: - Debug Actions Section

    private var debugActionsSection: some View {
        Section("Debug Actions") {
            Button {
                generateTestCrash()
            } label: {
                Label("Trigger Test Crash", systemImage: "exclamationmark.octagon")
                    .foregroundColor(.red)
            }

            Button {
                generateTestError()
            } label: {
                Label("Generate Test Error", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.orange)
            }

            Button {
                performanceMonitor.startMonitoring()
            } label: {
                Label("Start Performance Monitoring", systemImage: "gauge")
            }

            Button {
                performanceMonitor.stopMonitoring()
            } label: {
                Label("Stop Performance Monitoring", systemImage: "gauge.badge.xmark")
            }
        }
    }

    // MARK: - Helpers

    private func fpsColor(_ fps: Double) -> Color {
        switch fps {
        case 55...60: return .green
        case 45..<55: return .yellow
        case 30..<45: return .orange
        default: return .red
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private var deviceModel: String {
        #if os(iOS)
        return UIDevice.current.model
        #elseif os(macOS)
        return "Mac"
        #else
        return "Unknown"
        #endif
    }

    private var osVersion: String {
        #if os(iOS)
        return "iOS \(UIDevice.current.systemVersion)"
        #elseif os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion)"
        #else
        return "Unknown"
        #endif
    }

    // MARK: - Test Actions

    private func generateTestCrash() {
        let error = NSError(domain: "com.sekretar.test", code: 999, userInfo: [
            NSLocalizedDescriptionKey: "This is a test crash for TestFlight debugging"
        ])
        crashService.reportError(error, context: "Test crash triggered by user", severity: .fatal)
    }

    private func generateTestError() {
        let error = NSError(domain: "com.sekretar.test", code: 100, userInfo: [
            NSLocalizedDescriptionKey: "This is a test error"
        ])
        crashService.reportError(error, context: "Test error for debugging", severity: .error)
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct CrashDetailView: View {
    let crash: CrashReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(crash.displayTitle)
                            .font(.title2)
                            .bold()

                        Text(crash.timestamp, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()

                    Divider()

                    // Details
                    DetailSection(title: "Type", content: crash.type.rawValue)
                    DetailSection(title: "Reason", content: crash.reason)

                    if let context = crash.context {
                        DetailSection(title: "Context", content: context)
                    }

                    DetailSection(title: "App Version", content: crash.appVersion)
                    DetailSection(title: "OS Version", content: crash.osVersion)
                    DetailSection(title: "Device", content: crash.deviceModel)

                    // Stack Trace
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stack Trace")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(crash.stackTrace)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Crash Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(content)
                .font(.body)
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview
#if DEBUG
struct TestFlightDebugView_Previews: PreviewProvider {
    static var previews: some View {
        TestFlightDebugView()
    }
}
#endif
