import SwiftUI
import CoreData

// MARK: - Privacy Policy View
/// Экран политики конфиденциальности + GDPR compliance (BRD строки 469, 526-536)
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManagementService.shared
    @State private var showingExportSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var exportedDataURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    // Header
                    headerSection

                    Divider()

                    // Privacy Mode Toggle
                    privacyModeSection

                    Divider()

                    // Data Management
                    dataManagementSection

                    Divider()

                    // Privacy Policy Text
                    policyTextSection

                    Divider()

                    // Data Processing Agreement
                    dpaSection

                    Color.clear.frame(height: DesignSystem.Spacing.xl)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Privacy & Data")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportedDataURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Everything", role: .destructive) {
                    Task {
                        await dataManager.deleteAllUserData()
                    }
                }
            } message: {
                Text("This will permanently delete all your tasks, events, and settings. This action cannot be undone.")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.title)
                    .foregroundColor(.blue)

                VStack(alignment: .leading) {
                    Text("Privacy First")
                        .font(.title2)
                        .bold()

                    Text("Your data, your control")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Sekretar is designed with privacy as a core principle. All your data is stored locally on your device and encrypted.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, DesignSystem.Spacing.xs)
        }
    }

    // MARK: - Privacy Mode Section

    private var privacyModeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Privacy Mode")
                .font(.headline)

            Toggle(isOn: $dataManager.isPrivacyModeEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enhanced Privacy")
                        .font(.subheadline)

                    Text("Mask personal information before sending to cloud AI services")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.blue)

            if dataManager.isPrivacyModeEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Privacy mode active: emails, phone numbers, and addresses will be masked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Data Management Section (GDPR)

    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Data Management")
                .font(.headline)

            Text("In compliance with GDPR, you have full control over your data:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                // Export Data
                Button {
                    Task {
                        exportedDataURL = await dataManager.exportAllData()
                        showingExportSheet = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading) {
                            Text("Export Your Data")
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Text("Download all your data in JSON format")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Delete All Data
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)

                        VStack(alignment: .leading) {
                            Text("Delete All Data")
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Text("Permanently remove all your data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Data Statistics
                dataStatistics
            }
        }
    }

    private var dataStatistics: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Data")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                StatItem(
                    icon: "checkmark.circle.fill",
                    count: dataManager.taskCount,
                    label: "Tasks"
                )

                StatItem(
                    icon: "calendar",
                    count: dataManager.eventCount,
                    label: "Events"
                )

                StatItem(
                    icon: "folder.fill",
                    count: dataManager.projectCount,
                    label: "Projects"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Policy Text Section

    private var policyTextSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Privacy Policy")
                .font(.headline)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                PolicySection(
                    title: "Data Collection",
                    content: "Sekretar collects only the data you explicitly provide (tasks, events, notes). We do not collect any personal information without your consent."
                )

                PolicySection(
                    title: "Data Storage",
                    content: "All data is stored locally on your device using encrypted Core Data. Optional cloud sync uses your own iCloud account, which we never access."
                )

                PolicySection(
                    title: "AI Processing",
                    content: "When using AI features, your data may be sent to AI providers (on-device or cloud). Privacy Mode masks personal information before transmission."
                )

                PolicySection(
                    title: "Third-Party Services",
                    content: "We use EventKit for calendar integration and optional cloud AI providers. No data is shared with third parties for advertising or analytics without consent."
                )

                PolicySection(
                    title: "Data Retention",
                    content: "You control all data retention. Data is kept only as long as you choose. Delete functionality removes all data permanently."
                )

                PolicySection(
                    title: "Your Rights (GDPR)",
                    content: "You have the right to access, rectify, export, and delete your data at any time. Use the Data Management section above to exercise these rights."
                )
            }
        }
    }

    // MARK: - Data Processing Agreement Section

    private var dpaSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Data Processing")
                .font(.headline)

            Text("When using cloud AI features:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                BulletPoint(text: "Data is transmitted securely over HTTPS")
                BulletPoint(text: "Cloud providers process data according to their privacy policies")
                BulletPoint(text: "No logs are kept of your data content (metadata only)")
                BulletPoint(text: "Data retention: 0 days for content, 14-30 days for aggregates")
                BulletPoint(text: "You can disable cloud AI features at any time")
            }

            Text("Last updated: \(Date().formatted(date: .long, time: .omitted))")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, DesignSystem.Spacing.sm)
        }
    }
}

// MARK: - Supporting Views

struct PolicySection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .bold()

            Text(content)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct StatItem: View {
    let icon: String
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)

            Text("\(count)")
                .font(.headline)
                .bold()

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Share Sheet
#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Data Management Service
@MainActor
final class DataManagementService: ObservableObject {
    static let shared = DataManagementService()

    @Published var isPrivacyModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPrivacyModeEnabled, forKey: "privacy_mode_enabled")
        }
    }

    @Published var taskCount = 0
    @Published var eventCount = 0
    @Published var projectCount = 0

    private let context = PersistenceController.shared.container.viewContext

    private init() {
        self.isPrivacyModeEnabled = UserDefaults.standard.bool(forKey: "privacy_mode_enabled")
        updateStatistics()
    }

    // MARK: - Statistics

    func updateStatistics() {
        let taskRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        let eventRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        let projectRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()

        do {
            taskCount = try context.count(for: taskRequest)
            eventCount = try context.count(for: eventRequest)
            projectCount = try context.count(for: projectRequest)
        } catch {
            print("❌ Error fetching statistics: \(error)")
        }
    }

    // MARK: - Export Data (GDPR Right to Access)

    func exportAllData() async -> URL? {
        let exportData = await buildExportData()

        // Convert to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(exportData) else {
            print("❌ Error encoding export data")
            return nil
        }

        // Save to temporary file
        let fileName = "sekretar_export_\(Date().ISO8601Format()).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try jsonData.write(to: tempURL)
            print("✅ Data exported to: \(tempURL)")

            AnalyticsService.shared.track(.dataExported, properties: [
                "task_count": taskCount,
                "event_count": eventCount,
                "project_count": projectCount
            ])

            return tempURL
        } catch {
            print("❌ Error writing export file: \(error)")
            return nil
        }
    }

    private func buildExportData() async -> ExportData {
        var tasks: [[String: Any]] = []
        var events: [[String: Any]] = []
        var projects: [[String: Any]] = []

        await context.perform {
            // Export tasks
            let taskRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            if let taskEntities = try? self.context.fetch(taskRequest) {
                tasks = taskEntities.compactMap { task in
                    [
                        "id": task.id?.uuidString ?? "",
                        "title": task.title ?? "",
                        "notes": task.notes ?? "",
                        "priority": Int(task.priority),
                        "isCompleted": task.isCompleted,
                        "dueDate": task.dueDate?.ISO8601Format() ?? "",
                        "createdAt": task.createdAt?.ISO8601Format() ?? "",
                        "updatedAt": task.updatedAt?.ISO8601Format() ?? ""
                    ]
                }
            }

            // Export events
            let eventRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
            if let eventEntities = try? self.context.fetch(eventRequest) {
                events = eventEntities.compactMap { event in
                    [
                        "id": event.id?.uuidString ?? "",
                        "title": event.title ?? "",
                        "notes": event.notes ?? "",
                        "startDate": event.startDate?.ISO8601Format() ?? "",
                        "endDate": event.endDate?.ISO8601Format() ?? "",
                        "isAllDay": event.isAllDay
                    ]
                }
            }

            // Export projects
            let projectRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            if let projectEntities = try? self.context.fetch(projectRequest) {
                projects = projectEntities.compactMap { project in
                    [
                        "id": project.id?.uuidString ?? "",
                        "title": project.title ?? "",
                        "color": project.color ?? "",
                        "createdAt": project.createdAt?.ISO8601Format() ?? ""
                    ]
                }
            }
        }

        return ExportData(
            exportDate: Date().ISO8601Format(),
            tasks: tasks,
            events: events,
            projects: projects
        )
    }

    // MARK: - Delete All Data (GDPR Right to Erasure)

    func deleteAllUserData() async {
        await context.perform {
            // Delete all tasks
            let taskRequest: NSFetchRequest<NSFetchRequestResult> = TaskEntity.fetchRequest()
            let taskDelete = NSBatchDeleteRequest(fetchRequest: taskRequest)
            try? self.context.execute(taskDelete)

            // Delete all events
            let eventRequest: NSFetchRequest<NSFetchRequestResult> = EventEntity.fetchRequest()
            let eventDelete = NSBatchDeleteRequest(fetchRequest: eventRequest)
            try? self.context.execute(eventDelete)

            // Delete all projects
            let projectRequest: NSFetchRequest<NSFetchRequestResult> = ProjectEntity.fetchRequest()
            let projectDelete = NSBatchDeleteRequest(fetchRequest: projectRequest)
            try? self.context.execute(projectDelete)

            try? self.context.save()
        }

        // Clear all UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        updateStatistics()

        AnalyticsService.shared.track(.dataDeleted, properties: [:])

        print("✅ All user data deleted")
    }
}

// MARK: - Export Models
struct ExportData: Encodable {
    let exportDate: String
    let tasks: [[String: Any]]
    let events: [[String: Any]]
    let projects: [[String: Any]]

    enum CodingKeys: String, CodingKey {
        case exportDate
        case tasks
        case events
        case projects
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(exportDate, forKey: .exportDate)

        // Convert dictionaries to JSON-compatible format
        if let tasksData = try? JSONSerialization.data(withJSONObject: tasks),
           let tasksString = String(data: tasksData, encoding: .utf8) {
            try container.encode(tasksString, forKey: .tasks)
        }
        if let eventsData = try? JSONSerialization.data(withJSONObject: events),
           let eventsString = String(data: eventsData, encoding: .utf8) {
            try container.encode(eventsString, forKey: .events)
        }
        if let projectsData = try? JSONSerialization.data(withJSONObject: projects),
           let projectsString = String(data: projectsData, encoding: .utf8) {
            try container.encode(projectsString, forKey: .projects)
        }
    }
}

// MARK: - Analytics Extensions
extension AnalyticsEvent {
    static let dataExported = AnalyticsEvent(rawValue: "data_exported")!
    static let dataDeleted = AnalyticsEvent(rawValue: "data_deleted")!
}

// MARK: - Preview
#if DEBUG
struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPolicyView()
    }
}
#endif
