import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("defaultReminderTime") private var defaultReminderTime: Int = 9
    @AppStorage("showCompletedTasks") private var showCompletedTasks: Bool = true
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true

    @State private var showAbout = false
    @State private var showNotificationSettings = false

    var body: some View {
        NavigationStack {
            Form {
                // Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                // Task Settings
                Section("Tasks") {
                    Toggle("Show Completed Tasks", isOn: $showCompletedTasks)

                    Picker("Default Reminder Time", selection: $defaultReminderTime) {
                        ForEach(6..<22) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                }

                // Notifications
                Section("Notifications") {
                    Button {
                        showNotificationSettings = true
                    } label: {
                        HStack {
                            Text("Notification Settings")
                                .foregroundColor(Color.Taskweave.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.Taskweave.textTertiary)
                        }
                    }
                }

                // Accessibility
                Section("Accessibility") {
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                }

                // Data
                Section("Data") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Text("Data Management")
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(Color.Taskweave.textSecondary)
                    }

                    Button {
                        showAbout = true
                    } label: {
                        Text("About Taskweave")
                            .foregroundColor(Color.Taskweave.textPrimary)
                    }

                    Link(destination: URL(string: "https://connectwithprakash.github.io/taskweave/privacy/")!) {
                        Text("Privacy Policy")
                    }

                    Link(destination: URL(string: "https://connectwithprakash.github.io/taskweave/terms/")!) {
                        Text("Terms of Service")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    // App Icon
                    Image(systemName: "clock.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Color.Taskweave.accent)
                        .padding(.top, DesignSystem.Spacing.xxl)

                    // App Name
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Taskweave")
                            .font(DesignSystem.Typography.largeTitle)
                            .foregroundColor(Color.Taskweave.textPrimary)

                        Text("Calendar-First Todo App")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Taskweave.textSecondary)
                    }

                    // Description
                    Text("Taskweave helps engineers manage their tasks and time by seamlessly integrating todo lists with your calendar. See what's due, when you're free, and plan your day with ease.")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(Color.Taskweave.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.xxl)

                    Spacer()
                }
            }
            .navigationTitle("About")
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

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = false
    @State private var isCheckingPermission = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isCheckingPermission {
                        HStack {
                            ProgressView()
                            Text("Checking permissions...")
                                .foregroundColor(Color.Taskweave.textSecondary)
                        }
                    } else if notificationsEnabled {
                        Label("Notifications Enabled", systemImage: "checkmark.circle.fill")
                            .foregroundColor(Color.Taskweave.success)
                    } else {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("Notifications Disabled", systemImage: "xmark.circle.fill")
                                .foregroundColor(Color.Taskweave.error)

                            Text("Enable notifications in Settings to receive task reminders.")
                                .font(DesignSystem.Typography.footnote)
                                .foregroundColor(Color.Taskweave.textSecondary)

                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .padding(.top, DesignSystem.Spacing.xs)
                        }
                    }
                }

                Section("Reminder Types") {
                    Toggle("Task Due Reminders", isOn: .constant(true))
                    Toggle("Morning Daily Summary", isOn: .constant(false))
                    Toggle("Overdue Task Alerts", isOn: .constant(true))
                }
                .disabled(!notificationsEnabled)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await checkNotificationPermission()
            }
        }
    }

    private func checkNotificationPermission() async {
        let status = await NotificationService.shared.checkPermissionStatus()
        notificationsEnabled = status == .authorized
        isCheckingPermission = false
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        Form {
            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text("Delete All Data")
                    }
                }
                .disabled(isDeleting)
            } footer: {
                Text("This will permanently delete all tasks, lists, and settings. This action cannot be undone.")
            }

            Section("iCloud Sync") {
                HStack {
                    Text("Sync Status")
                    Spacer()
                    Text("Enabled")
                        .foregroundColor(Color.Taskweave.success)
                }

                HStack {
                    Text("Last Synced")
                    Spacer()
                    Text("Just now")
                        .foregroundColor(Color.Taskweave.textSecondary)
                }
            }
        }
        .navigationTitle("Data Management")
        .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("This will permanently delete all your tasks, lists, and settings. This action cannot be undone.")
        }
    }

    private func deleteAllData() {
        isDeleting = true
        PersistenceController.shared.deleteAllData()
        PersistenceController.shared.createDefaultListsIfNeeded()
        isDeleting = false
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
