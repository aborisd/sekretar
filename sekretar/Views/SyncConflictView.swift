import SwiftUI

/// Conflict resolution view
struct SyncConflictView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var syncService = SyncService.shared

    let conflict: SyncConflict

    @State private var selectedResolution: ResolutionType = .useServer
    @State private var isResolving = false
    @State private var showError = false
    @State private var errorMessage = ""

    enum ResolutionType {
        case useLocal
        case useServer
        case manual
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Conflict Detected")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("This \(conflict.entityType) was modified both locally and on the server. Choose how to resolve:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Resolution options
                    VStack(spacing: 12) {
                        // Use Server Version
                        ResolutionOptionCard(
                            title: "Use Server Version",
                            description: "Discard local changes and use the version from the server",
                            lastModified: conflict.serverUpdatedAt,
                            isSelected: selectedResolution == .useServer,
                            icon: "cloud.fill",
                            color: .blue
                        ) {
                            selectedResolution = .useServer
                        }

                        // Use Local Version
                        ResolutionOptionCard(
                            title: "Use Local Version",
                            description: "Keep local changes and overwrite the server version",
                            lastModified: conflict.localUpdatedAt,
                            isSelected: selectedResolution == .useLocal,
                            icon: "iphone",
                            color: .green
                        ) {
                            selectedResolution = .useLocal
                        }

                        // Manual Merge (Future)
                        ResolutionOptionCard(
                            title: "Merge Manually",
                            description: "Review both versions and choose specific fields (coming soon)",
                            lastModified: nil,
                            isSelected: selectedResolution == .manual,
                            icon: "arrow.triangle.merge",
                            color: .orange,
                            isDisabled: true
                        ) {
                            selectedResolution = .manual
                        }
                    }
                    .padding(.horizontal)

                    // Comparison View
                    if selectedResolution != .manual {
                        Divider()
                            .padding(.vertical)

                        ComparisonView(
                            localData: conflict.localData,
                            serverData: conflict.serverData,
                            entityType: conflict.entityType
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isResolving)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Resolve") {
                        resolveConflict()
                    }
                    .disabled(isResolving || selectedResolution == .manual)
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if isResolving {
                    ProgressView("Resolving...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func resolveConflict() {
        isResolving = true

        Task {
            do {
                let resolution: ConflictResolution
                switch selectedResolution {
                case .useLocal:
                    resolution = .useLocal
                case .useServer:
                    resolution = .useServer
                case .manual:
                    return  // Not implemented yet
                }

                try await syncService.resolveConflict(conflict, resolution: resolution)

                await MainActor.run {
                    isResolving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isResolving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

/// Resolution option card
struct ResolutionOptionCard: View {
    let title: String
    let description: String
    let lastModified: Date?
    let isSelected: Bool
    let icon: String
    let color: Color
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isDisabled ? .gray : color)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill((isDisabled ? Color.gray : color).opacity(0.1))
                    )

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isDisabled ? .gray : .primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    if let lastModified = lastModified {
                        Text("Modified: \(lastModified, style: .relative) ago")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(color)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.05) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? color : Color(.separator), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

/// Comparison view for local vs server data
struct ComparisonView: View {
    let localData: [String: Any]
    let serverData: [String: Any]
    let entityType: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview Changes")
                .font(.headline)

            HStack(alignment: .top, spacing: 16) {
                // Local version
                VStack(alignment: .leading, spacing: 8) {
                    Label("Local Version", systemImage: "iphone")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)

                    DataPreview(data: localData, entityType: entityType)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                // Server version
                VStack(alignment: .leading, spacing: 8) {
                    Label("Server Version", systemImage: "cloud.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)

                    DataPreview(data: serverData, entityType: entityType)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

/// Data preview component
struct DataPreview: View {
    let data: [String: Any]
    let entityType: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entityType == "task" {
                if let title = data["title"] as? String {
                    DataRow(label: "Title", value: title)
                }
                if let isCompleted = data["isCompleted"] as? Bool {
                    DataRow(label: "Status", value: isCompleted ? "Completed" : "Pending")
                }
                if let priority = data["priority"] as? String {
                    DataRow(label: "Priority", value: priority.capitalized)
                }
            } else if entityType == "event" {
                if let title = data["title"] as? String {
                    DataRow(label: "Title", value: title)
                }
                if let location = data["location"] as? String {
                    DataRow(label: "Location", value: location)
                }
                if let startDate = data["startDate"] as? Date {
                    DataRow(label: "Start", value: startDate.formatted())
                }
            }
        }
    }
}

/// Data row in preview
struct DataRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .lineLimit(2)
        }
    }
}

/// Badge showing number of pending conflicts
struct ConflictBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            ZStack {
                Circle()
                    .fill(.red)
                    .frame(width: 20, height: 20)

                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    SyncConflictView(conflict: SyncConflict(
        entityType: "task",
        entityId: UUID(),
        localVersion: 2,
        serverVersion: 3,
        localUpdatedAt: Date().addingTimeInterval(-3600),
        serverUpdatedAt: Date().addingTimeInterval(-1800),
        localData: [
            "title": "Complete project",
            "isCompleted": false,
            "priority": "high"
        ],
        serverData: [
            "title": "Complete project report",
            "isCompleted": true,
            "priority": "medium"
        ]
    ))
}
