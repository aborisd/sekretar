import SwiftUI
import CoreData

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingPrivacyPolicy = false
    @State private var showingDebugView = false

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            List {
                // App Settings
                Section(LocalizedStringKey("settings.general")) {
                    Picker(LocalizedStringKey("settings.theme"), selection: $viewModel.selectedTheme) {
                        ForEach(SettingsViewModel.AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .onChange(of: viewModel.selectedTheme) { _, _ in
                        viewModel.saveSettings()
                    }

                    Picker(LocalizedStringKey("settings.language"), selection: $viewModel.selectedLanguage) {
                        ForEach(SettingsViewModel.AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .onChange(of: viewModel.selectedLanguage) { _, _ in
                        viewModel.saveSettings()
                    }
                }

                // Permissions
                Section(LocalizedStringKey("settings.permissions")) {
                    Toggle(LocalizedStringKey("settings.notifications"), isOn: $viewModel.notificationsEnabled)
                        .onChange(of: viewModel.notificationsEnabled) { _, newValue in
                            if newValue {
                                Task {
                                    await viewModel.requestNotificationPermission()
                                }
                            }
                        }

                    Button {
                        Task {
                            await viewModel.requestCalendarPermission()
                        }
                    } label: {
                        HStack {
                            Text(LocalizedStringKey("settings.calendar_access"))
                            Spacer()
                            if viewModel.calendarPermissionGranted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                // Working Hours
                Section(LocalizedStringKey("settings.working_hours")) {
                    DatePicker(LocalizedStringKey("settings.work_start"),
                              selection: $viewModel.workingHoursStart,
                              displayedComponents: .hourAndMinute)
                        .onChange(of: viewModel.workingHoursStart) { _, _ in
                            viewModel.saveSettings()
                        }

                    DatePicker(LocalizedStringKey("settings.work_end"),
                              selection: $viewModel.workingHoursEnd,
                              displayedComponents: .hourAndMinute)
                        .onChange(of: viewModel.workingHoursEnd) { _, _ in
                            viewModel.saveSettings()
                        }
                }

                // Privacy & Data
                Section(LocalizedStringKey("settings.privacy_data")) {
                    Button {
                        showingPrivacyPolicy = true
                    } label: {
                        HStack {
                            Label(LocalizedStringKey("privacy.title"), systemImage: "lock.shield")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }

                // Debug (TestFlight only)
                #if DEBUG
                Section(LocalizedStringKey("settings.debug")) {
                    Toggle(LocalizedStringKey("settings.debug_mode"), isOn: $viewModel.debugModeEnabled)
                        .onChange(of: viewModel.debugModeEnabled) { _, _ in
                            viewModel.saveSettings()
                        }

                    Button {
                        showingDebugView = true
                    } label: {
                        HStack {
                            Label("TestFlight Debug", systemImage: "hammer.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                #endif

                // About
                Section(LocalizedStringKey("settings.about")) {
                    HStack {
                        Text(LocalizedStringKey("settings.version"))
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(LocalizedStringKey("settings.build"))
                        Spacer()
                        Text(buildNumber)
                            .foregroundColor(.secondary)
                    }
                }

                // Actions
                Section {
                    Button(role: .destructive) {
                        viewModel.resetAllSettings()
                    } label: {
                        Text(LocalizedStringKey("settings.reset_all"))
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("settings.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("common.done")) {
                        viewModel.saveSettings()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showingDebugView) {
                TestFlightDebugView()
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
