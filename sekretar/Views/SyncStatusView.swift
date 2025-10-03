import SwiftUI

/// Sync status indicator view
struct SyncStatusView: View {
    @StateObject private var syncService = SyncService.shared
    @State private var showConflicts = false

    var body: some View {
        HStack(spacing: 8) {
            // Sync status icon
            if syncService.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Syncing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let lastSync = syncService.lastSyncDate {
                Image(systemName: "checkmark.icloud")
                    .foregroundColor(.green)
                Text("Synced \(lastSync, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "icloud.slash")
                    .foregroundColor(.orange)
                Text("Not synced")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Conflict indicator
            if !syncService.pendingConflicts.isEmpty {
                Button {
                    showConflicts = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("\(syncService.pendingConflicts.count) conflicts")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.red.opacity(0.1))
                    )
                }
            }
        }
        .sheet(isPresented: $showConflicts) {
            ConflictListView()
        }
    }
}

/// List of pending conflicts
struct ConflictListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var syncService = SyncService.shared
    @State private var selectedConflict: SyncConflict?

    var body: some View {
        NavigationView {
            List {
                if syncService.pendingConflicts.isEmpty {
                    ContentUnavailableView(
                        "No Conflicts",
                        systemImage: "checkmark.circle",
                        description: Text("All items are synchronized")
                    )
                } else {
                    ForEach(syncService.pendingConflicts) { conflict in
                        ConflictRow(conflict: conflict)
                            .onTapGesture {
                                selectedConflict = conflict
                            }
                    }
                }
            }
            .navigationTitle("Sync Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedConflict) { conflict in
                SyncConflictView(conflict: conflict)
            }
        }
    }
}

/// Single conflict row
struct ConflictRow: View {
    let conflict: SyncConflict

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: conflict.entityType == "task" ? "checkmark.circle" : "calendar")
                    .foregroundColor(.orange)

                Text(conflict.entityType.capitalized)
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local: v\(conflict.localVersion)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(conflict.localUpdatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundColor(.orange)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Server: v\(conflict.serverVersion)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(conflict.serverUpdatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Sync settings view
struct SyncSettingsView: View {
    @StateObject private var syncService = SyncService.shared
    @StateObject private var authManager = AuthManager.shared

    @State private var autoSyncEnabled = true
    @State private var isSyncing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        List {
            // Status section
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    if syncService.isSyncing {
                        ProgressView()
                    } else if let lastSync = syncService.lastSyncDate {
                        Text("Synced \(lastSync, style: .relative) ago")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Never synced")
                            .foregroundColor(.secondary)
                    }
                }

                if let stats = syncService.lastSyncStats {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.up.circle")
                            Text("Pushed: \(stats.totalPushed) items")
                        }
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Pulled: \(stats.totalPulled) items")
                        }
                        if stats.conflictsDetected > 0 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("Conflicts: \(stats.conflictsDetected)")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            } header: {
                Text("Sync Status")
            }

            // Actions section
            Section {
                Button {
                    manualSync()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Now")
                    }
                }
                .disabled(syncService.isSyncing)

                if !syncService.pendingConflicts.isEmpty {
                    NavigationLink {
                        ConflictListView()
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Resolve Conflicts")
                            Spacer()
                            ConflictBadge(count: syncService.pendingConflicts.count)
                        }
                    }
                }
            } header: {
                Text("Actions")
            }

            // Settings section
            Section {
                Toggle("Auto Sync", isOn: $autoSyncEnabled)
                    .onChange(of: autoSyncEnabled) { newValue in
                        if newValue {
                            syncService.scheduleBackgroundSync()
                        }
                    }
            } header: {
                Text("Settings")
            } footer: {
                Text("Automatically sync in the background when changes are made")
            }

            // Account section
            Section {
                if let user = authManager.currentUser {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.email)
                        Text(user.subscriptionTier.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Sign Out") {
                        Task {
                            await authManager.logout()
                        }
                    }
                    .foregroundColor(.red)
                } else {
                    Text("Not signed in")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Account")
            }
        }
        .navigationTitle("Sync & Account")
        .alert("Sync Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func manualSync() {
        isSyncing = true

        Task {
            do {
                _ = try await syncService.sync(force: true)
                await MainActor.run {
                    isSyncing = false
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SyncSettingsView()
    }
}
