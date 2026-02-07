import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("defaultReminderTime") private var defaultReminderTime: Int = 9
    @AppStorage("showCompletedTasks") private var showCompletedTasks: Bool = true
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true
    @AppStorage("summaryPromptHour") private var summaryPromptHour: Int = 18

    @State private var showAbout = false
    @State private var showNotificationSettings = false
    @State private var showAISettings = false

    var body: some View {
        // No NavigationStack - parent provides navigation context
        // iPad: NavigationSplitView, iPhone: MoreView's NavigationStack
        settingsForm
            .frame(maxWidth: horizontalSizeClass == .regular ? 700 : .infinity)
            .frame(maxWidth: .infinity)
            .navigationTitle("Settings")
            .sheet(isPresented: $showAbout) { AboutView() }
            .sheet(isPresented: $showNotificationSettings) { NotificationSettingsView() }
            .sheet(isPresented: $showAISettings) { AISettingsView() }
    }

    private var settingsForm: some View {
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
                                .foregroundColor(Color.Lazyflow.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.Lazyflow.textTertiary)
                        }
                    }
                }

                // Morning Briefing
                Section {
                    MorningBriefingPromptToggle()
                    MorningBriefingNotificationToggle()
                } header: {
                    Text("Morning Briefing")
                } footer: {
                    Text("Get a prompt card on Today and optional notification to view your morning briefing. Access it anytime from More > Morning Briefing.")
                }

                // Plan Your Day
                Section {
                    Toggle("Auto-Hide Frequently Skipped", isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "autoHideSkippedEvents") },
                        set: { UserDefaults.standard.set($0, forKey: "autoHideSkippedEvents") }
                    ))
                } header: {
                    Text("Plan Your Day")
                } footer: {
                    Text("Events you consistently skip will be hidden by default. You can always reveal them.")
                }

                // Daily Summary Notifications
                Section {
                    DailySummaryNotificationToggle()

                    Picker("Show Prompt After", selection: $summaryPromptHour) {
                        ForEach(12..<22, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                } header: {
                    Text("Daily Summary")
                } footer: {
                    Text("Get a notification and prompt card to review your day. Access your summary anytime from More > Daily Summary.")
                }

                // Live Activity
                Section {
                    LiveActivityToggle()
                } header: {
                    Text("Live Activity")
                } footer: {
                    Text("Shows task progress on Lock Screen and Dynamic Island (iPhone 14+)")
                }

                // Accessibility
                Section("Accessibility") {
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                }

                // AI Features
                Section("AI Features") {
                    Button {
                        showAISettings = true
                    } label: {
                        HStack {
                            Label("AI Settings", systemImage: "brain")
                                .foregroundColor(Color.Lazyflow.textPrimary)
                            Spacer()
                            if LLMService.shared.isReady {
                                Text(LLMService.shared.selectedProvider.displayName)
                                    .font(DesignSystem.Typography.footnote)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.Lazyflow.success)
                            } else {
                                Text("Configure")
                                    .font(DesignSystem.Typography.footnote)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.Lazyflow.textTertiary)
                        }
                    }
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
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }

                    Button {
                        showAbout = true
                    } label: {
                        Text("About Lazyflow")
                            .foregroundColor(Color.Lazyflow.textPrimary)
                    }

                    Link(destination: URL(string: "https://lazyflow.netlify.app/privacy/")!) {
                        Text("Privacy Policy")
                    }

                    Link(destination: URL(string: "https://lazyflow.netlify.app/terms/")!) {
                        Text("Terms of Service")
                    }
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
                        .foregroundColor(Color.Lazyflow.accent)
                        .padding(.top, DesignSystem.Spacing.xxl)

                    // App Name
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Lazyflow")
                            .font(DesignSystem.Typography.largeTitle)
                            .foregroundColor(Color.Lazyflow.textPrimary)

                        Text("Calendar-First Todo App")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }

                    // Description
                    Text("Lazyflow helps engineers manage their tasks and time by seamlessly integrating todo lists with your calendar. See what's due, when you're free, and plan your day with ease.")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(Color.Lazyflow.textSecondary)
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
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    } else if notificationsEnabled {
                        Label("Notifications Enabled", systemImage: "checkmark.circle.fill")
                            .foregroundColor(Color.Lazyflow.success)
                    } else {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("Notifications Disabled", systemImage: "xmark.circle.fill")
                                .foregroundColor(Color.Lazyflow.error)

                            Text("Enable notifications in Settings to receive task reminders. Tap Open Settings, then tap Notifications.")
                                .font(DesignSystem.Typography.footnote)
                                .foregroundColor(Color.Lazyflow.textSecondary)

                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .padding(.top, DesignSystem.Spacing.xs)
                        }
                    }
                }

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
        var status = await NotificationService.shared.checkPermissionStatus()

        // If permission hasn't been requested yet, request it now
        // This ensures the Notifications option appears in iOS Settings
        if status == .notDetermined {
            let granted = await NotificationService.shared.requestPermission()
            status = granted ? .authorized : .denied
        }

        notificationsEnabled = status == .authorized || status == .provisional || status == .ephemeral
        isCheckingPermission = false
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @State private var iCloudSyncEnabled = PersistenceController.isICloudSyncEnabled
    @State private var syncStatus: SyncStatus = .disabled
    @State private var localDataCounts = DataCounts(tasks: 0, lists: 0)
    @State private var cloudCountsResult: PersistenceController.CloudCountsResult?
    @State private var isLoadingCloudCounts = false
    @State private var isDeleting = false
    @State private var isDeletingCloud = false

    // Delete confirmation states
    @State private var showDeleteLocalConfirmation = false
    @State private var showDeleteEverywhereConfirmation = false
    @State private var showDeleteCloudOnlyConfirmation = false
    @State private var showResyncConfirmation = false
    @State private var showResetEventPreferencesConfirmation = false

    private var iCloudAvailable: Bool {
        PersistenceController.isICloudAvailable
    }

    /// Extract DataCounts from result if successful
    private var cloudDataCounts: DataCounts? {
        guard case .success(let counts) = cloudCountsResult else { return nil }
        return counts
    }

    /// Get error message from result if error
    private var cloudCountsError: String? {
        guard case .error(let message) = cloudCountsResult else { return nil }
        return message
    }

    /// Computed sync status text with icon
    @ViewBuilder
    private var syncStatusText: some View {
        if !iCloudSyncEnabled {
            Text("Tasks stored locally only")
        } else {
            switch syncStatus {
            case .synced(let date):
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.Lazyflow.success)
                        .font(.caption)
                    Text("Synced · \(timeAgo(from: date))")
                }
            case .syncing:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Syncing...")
                }
            case .pendingChanges(let count):
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(Color.Lazyflow.warning)
                        .font(.caption)
                    Text("\(count) change\(count == 1 ? "" : "s") pending")
                }
            case .offline:
                HStack(spacing: 4) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(Color.Lazyflow.warning)
                        .font(.caption)
                    Text("Offline · Changes will sync when online")
                }
            case .disabled:
                Text("Tasks stored locally only")
            case .error(let message):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Color.Lazyflow.error)
                        .font(.caption)
                    Text(message)
                }
            }
        }
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        Form {
            // MARK: - iCloud Sync Section
            Section {
                Toggle(isOn: $iCloudSyncEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: iCloudSyncEnabled ? "icloud.fill" : "icloud.slash")
                            .font(.title2)
                            .foregroundColor(iCloudSyncEnabled ? Color.Lazyflow.accent : Color.Lazyflow.textTertiary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud Sync")
                            syncStatusText
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }
                }
                .disabled(!iCloudAvailable)
                .onChange(of: iCloudSyncEnabled) { _, newValue in
                    PersistenceController.setICloudSyncEnabled(newValue)
                    // Reload store with new sync settings immediately
                    PersistenceController.shared.reloadStoreWithCurrentSyncSettings()
                    // Refresh data after reload
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        refreshData()
                    }
                }

                if !iCloudAvailable {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color.Lazyflow.warning)
                        Text("Sign in to iCloud in Settings to enable sync")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                }
            } header: {
                Text("iCloud")
            } footer: {
                if iCloudAvailable && iCloudSyncEnabled {
                    Text("Tasks sync automatically when you make changes.")
                } else if iCloudAvailable {
                    Text("Enable to sync tasks across your Apple devices.")
                }
            }

            // MARK: - Data Overview Section
            Section("Storage") {
                // Local storage
                HStack {
                    Image(systemName: "iphone")
                        .foregroundColor(Color.Lazyflow.accent)
                        .frame(width: 28)
                    Text("On This Device")
                    Spacer()
                    Text(localDataCounts.description)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                // iCloud storage (only show if iCloud is available)
                if iCloudAvailable {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(iCloudSyncEnabled ? Color.Lazyflow.accent : Color.Lazyflow.textTertiary)
                            .frame(width: 28)
                        Text("In iCloud")
                        Spacer()
                        if isLoadingCloudCounts {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if let cloudCounts = cloudDataCounts {
                            if cloudCounts.isEmpty {
                                Text("Empty")
                                    .foregroundColor(Color.Lazyflow.textTertiary)
                            } else {
                                Text(cloudCounts.description)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }
                        } else if let error = cloudCountsError {
                            Button {
                                fetchCloudCounts()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Color.Lazyflow.warning)
                                        .font(.caption)
                                    Text(error)
                                        .foregroundColor(Color.Lazyflow.warning)
                                }
                                .font(DesignSystem.Typography.caption1)
                            }
                        } else if !iCloudSyncEnabled {
                            Text("Sync disabled")
                                .foregroundColor(Color.Lazyflow.textTertiary)
                                .font(DesignSystem.Typography.caption1)
                        } else {
                            Button("Check") {
                                fetchCloudCounts()
                            }
                            .font(DesignSystem.Typography.caption1)
                        }
                    }
                }

                if iCloudSyncEnabled && iCloudAvailable {
                    Button {
                        showResyncConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .frame(width: 28)
                            Text("Re-sync from iCloud")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color.Lazyflow.textTertiary)
                        }
                    }
                    .foregroundColor(Color.Lazyflow.textPrimary)
                }
            }

            // MARK: - Danger Zone Section
            Section {
                // Option 1: Clear Local Cache
                Button(role: .destructive) {
                    showDeleteLocalConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear Local Cache")
                            if iCloudSyncEnabled {
                                Text("Re-downloads from iCloud")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            } else if iCloudAvailable {
                                Text("Local only · iCloud backup kept")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            } else {
                                Text("Removes all local data")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }
                        }
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isDeleting || isDeletingCloud || localDataCounts.isEmpty)

                // Option 2: Delete Everything
                Button(role: .destructive) {
                    showDeleteEverywhereConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete Everything")
                            Text(iCloudAvailable ? "Local + iCloud · All devices" : "Local data only")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                        Spacer()
                    }
                }
                .disabled(isDeleting || isDeletingCloud || localDataCounts.isEmpty)

                // Option 3: Delete iCloud Data (only when sync disabled but iCloud available)
                if !iCloudSyncEnabled && iCloudAvailable {
                    Button(role: .destructive) {
                        showDeleteCloudOnlyConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "icloud.slash.fill")
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Delete iCloud Data")
                                Text("Cloud only · Keeps local data")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }
                            Spacer()
                            if isDeletingCloud {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isDeleting || isDeletingCloud)
                }

                // Option 4: Reset Event Preferences
                Button(role: .destructive) {
                    showResetEventPreferencesConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset Event Preferences")
                            Text("Clears learned Plan Your Day patterns")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                        Spacer()
                    }
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                if iCloudSyncEnabled {
                    Label(
                        "\"Delete Everything\" will remove data from ALL devices synced with this iCloud account.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundColor(Color.Lazyflow.warning)
                } else if iCloudAvailable {
                    Label(
                        "Sync is disabled. Data in iCloud will NOT be deleted unless you use \"Delete iCloud Data\".",
                        systemImage: "info.circle.fill"
                    )
                } else {
                    Text("Data is stored locally on this device only.")
                }
            }
        }
        .navigationTitle("Data Management")
        .onAppear {
            refreshData()
        }
        // MARK: - Alerts
        .alert("Clear Local Cache?", isPresented: $showDeleteLocalConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Cache", role: .destructive) {
                clearLocalData()
            }
        } message: {
            if iCloudSyncEnabled {
                Text("This will clear local data and re-download from iCloud. Your data is safe in the cloud.")
            } else {
                Text("This will permanently delete all data from this device. This cannot be undone.")
            }
        }
        .alert("Delete Everything?", isPresented: $showDeleteEverywhereConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteEverything()
            }
        } message: {
            if iCloudSyncEnabled {
                Text("⚠️ This will permanently delete all tasks and lists from this device AND all other devices synced with your iCloud account. This cannot be undone!")
            } else {
                Text("This will permanently delete all tasks and lists from this device. This cannot be undone.")
            }
        }
        .alert("Delete iCloud Data?", isPresented: $showDeleteCloudOnlyConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete from iCloud", role: .destructive) {
                deleteCloudData()
            }
        } message: {
            Text("This will delete all your data stored in iCloud. Local data on this device will not be affected. Other devices will lose their synced data.")
        }
        .alert("Re-sync from iCloud?", isPresented: $showResyncConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Re-sync", role: .destructive) {
                resyncFromCloud()
            }
        } message: {
            Text("This will replace local data with data from iCloud. Any unsynced local changes will be lost.")
        }
        .alert("Reset Event Preferences?", isPresented: $showResetEventPreferencesConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                EventPreferenceLearningService.shared.clearAllLearningData()
            }
        } message: {
            Text("This will clear all learned event preferences. The app will need to re-learn which events you typically skip or select.")
        }
    }

    // MARK: - Actions

    private func refreshData() {
        syncStatus = PersistenceController.shared.getSyncStatus()
        localDataCounts = PersistenceController.shared.getLocalDataCounts()

        // Auto-fetch cloud counts if iCloud is available and sync is enabled
        if iCloudAvailable && iCloudSyncEnabled {
            fetchCloudCounts()
        } else {
            // Clear cloud counts if sync is disabled
            cloudCountsResult = nil
        }
    }

    private func fetchCloudCounts() {
        guard !isLoadingCloudCounts else { return }
        isLoadingCloudCounts = true

        _Concurrency.Task {
            let result = await PersistenceController.shared.getCloudDataCountsWithError()
            await MainActor.run {
                cloudCountsResult = result
                isLoadingCloudCounts = false
                // Also refresh sync status since cloud query succeeded/failed
                syncStatus = PersistenceController.shared.getSyncStatus()
            }
        }
    }

    private func clearLocalData() {
        isDeleting = true
        PersistenceController.shared.deleteLocalDataOnly()

        // Wait for store to reload, then refresh
        // Don't create defaults here - let CloudKit re-sync or app will create on next view load
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            refreshData()
            isDeleting = false
        }
    }

    private func deleteEverything() {
        isDeleting = true

        // Delete local data
        PersistenceController.shared.deleteAllDataEverywhere()

        // If iCloud is available, also delete cloud data directly
        if iCloudAvailable {
            _Concurrency.Task {
                try? await PersistenceController.shared.deleteCloudKitData()
                await MainActor.run {
                    refreshData()
                    isDeleting = false
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                refreshData()
                isDeleting = false
            }
        }
    }

    private func deleteCloudData() {
        isDeletingCloud = true
        _Concurrency.Task {
            do {
                try await PersistenceController.shared.deleteCloudKitData()
            } catch {
                print("Failed to delete CloudKit data: \(error)")
            }
            await MainActor.run {
                isDeletingCloud = false
                refreshData()
            }
        }
    }

    private func resyncFromCloud() {
        isDeleting = true
        PersistenceController.shared.resyncFromCloud()
        // Data will refresh via CloudKit sync notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            refreshData()
            isDeleting = false
        }
    }
}

// MARK: - Batch Analysis Result Model

struct BatchAnalysisResult: Identifiable {
    let id = UUID()
    let task: Task
    let analysis: TaskAnalysis
    var isSelected: Bool = true

    /// Check if title was changed by AI
    var hasTitleChange: Bool {
        guard let refined = analysis.refinedTitle else { return false }
        return refined != task.title
    }
}

// MARK: - AI Settings View

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var llmService = LLMService.shared
    @StateObject private var taskService = TaskService.shared
    @AppStorage("aiAutoSuggest") private var aiAutoSuggest: Bool = true
    @AppStorage("aiEstimateDuration") private var aiEstimateDuration: Bool = true
    @AppStorage("aiSuggestPriority") private var aiSuggestPriority: Bool = true

    @State private var isBatchAnalyzing = false
    @State private var batchAnalysisProgress: Int = 0
    @State private var batchAnalysisTotal: Int = 0
    @State private var showBatchReviewSheet = false
    @State private var batchResults: [BatchAnalysisResult] = []
    @State private var configProviderType: LLMProviderType?

    var body: some View {
        NavigationStack {
            Form {
                // Provider Selection Section
                Section {
                    ForEach(LLMProviderType.allCases) { provider in
                        providerRow(for: provider)
                    }
                } header: {
                    Text("AI Provider")
                } footer: {
                    providerFooterText
                }

                // AI Features Section
                Section("AI Features") {
                    Toggle(isOn: $aiAutoSuggest) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Suggest")
                            Text("Show AI suggestions when creating tasks")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }

                    Toggle(isOn: $aiEstimateDuration) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Estimate Duration")
                            Text("AI estimates how long tasks will take")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }

                    Toggle(isOn: $aiSuggestPriority) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Suggest Priority")
                            Text("AI suggests task priority levels")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }
                }
                .disabled(!llmService.isReady)

                // Batch Analysis Section
                Section {
                    Button {
                        runBatchAnalysis()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(Color.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Analyze Uncategorized Tasks")
                                    .foregroundColor(Color.Lazyflow.textPrimary)
                                Text("\(uncategorizedTaskCount) tasks need categorization")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }
                            Spacer()
                            if isBatchAnalyzing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!llmService.isReady || isBatchAnalyzing || uncategorizedTaskCount == 0)

                    if isBatchAnalyzing {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            HStack {
                                Text("Analyzing...")
                                    .font(DesignSystem.Typography.footnote)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                                Spacer()
                                Text("\(batchAnalysisProgress)/\(batchAnalysisTotal)")
                                    .font(DesignSystem.Typography.footnote)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }
                            ProgressView(value: Double(batchAnalysisProgress), total: Double(batchAnalysisTotal))
                                .tint(Color.purple)
                        }
                    }
                } header: {
                    Text("Batch Analysis")
                } footer: {
                    Text("Automatically categorize and estimate duration for tasks without a category.")
                }
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showBatchReviewSheet) {
                BatchAnalysisReviewSheet(
                    results: $batchResults,
                    onApply: applyBatchResults
                )
            }
            .sheet(item: $configProviderType) { providerType in
                ProviderConfigurationSheet(providerType: providerType)
            }
        }
    }

    // MARK: - Provider UI

    @ViewBuilder
    private func providerRow(for provider: LLMProviderType) -> some View {
        Button {
            if provider == .apple {
                llmService.selectedProvider = provider
            } else if llmService.availableProviders.contains(provider) {
                if llmService.selectedProvider == provider {
                    // Already selected - tap again to edit
                    configProviderType = provider
                } else {
                    // Select this provider
                    llmService.selectedProvider = provider
                }
            } else {
                // Need to configure first
                configProviderType = provider
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: provider.iconName)
                    .font(.title2)
                    .foregroundColor(llmService.selectedProvider == provider ? Color.Lazyflow.accent : Color.Lazyflow.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(provider.displayName)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(Color.Lazyflow.textPrimary)

                        // Show "External" badge for providers that send data externally
                        if provider.isExternal {
                            Text("External")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.8))
                                .cornerRadius(4)
                        }
                    }

                    Text(provider.description)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                Spacer()

                // Selection indicator
                if llmService.selectedProvider == provider {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.Lazyflow.accent)
                } else if llmService.availableProviders.contains(provider) {
                    Image(systemName: "circle")
                        .foregroundColor(Color.Lazyflow.textTertiary)
                } else if provider != .apple {
                    Text("Configure")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.accent)
                }

                // Edit chevron for configured non-Apple providers
                if provider != .apple && llmService.availableProviders.contains(provider) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Lazyflow.textTertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if provider != .apple && llmService.availableProviders.contains(provider) {
                Button {
                    configProviderType = provider
                } label: {
                    Label("Edit Configuration", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    llmService.removeOpenResponsesProvider(type: provider)
                } label: {
                    Label("Remove Provider", systemImage: "trash")
                }
            }
        }
    }

    private var providerFooterText: Text {
        let provider = llmService.selectedProvider
        switch provider {
        case .apple:
            return Text("Apple Intelligence runs entirely on your device. No data leaves your device. Requires iOS 18.4 or later.")
        case .ollama:
            return Text("Ollama runs locally on your Mac. Your data stays on your local network.")
        case .custom:
            return Text("⚠️ Custom endpoints may send your task data to external servers. Ensure you trust the endpoint provider.")
        }
    }

    // MARK: - Computed Properties

    private var uncategorizedTaskCount: Int {
        taskService.tasks.filter { $0.category == .uncategorized && !$0.isCompleted }.count
    }

    // MARK: - Batch Analysis

    private func runBatchAnalysis() {
        let uncategorizedTasks = taskService.tasks.filter { $0.category == .uncategorized && !$0.isCompleted }
        guard !uncategorizedTasks.isEmpty else { return }

        isBatchAnalyzing = true
        batchAnalysisProgress = 0
        batchAnalysisTotal = uncategorizedTasks.count
        batchResults = []

        _Concurrency.Task {
            var results: [BatchAnalysisResult] = []

            for task in uncategorizedTasks {
                do {
                    let analysis = try await llmService.analyzeTask(task)

                    // Collect the result for review (don't apply yet)
                    await MainActor.run {
                        results.append(BatchAnalysisResult(task: task, analysis: analysis))
                        batchAnalysisProgress += 1
                    }
                } catch {
                    await MainActor.run {
                        batchAnalysisProgress += 1
                    }
                }

                // Small delay to avoid rate limiting
                try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }

            await MainActor.run {
                isBatchAnalyzing = false
                batchResults = results
                if !results.isEmpty {
                    showBatchReviewSheet = true
                }
            }
        }
    }

    private func applyBatchResults() {
        let selectedResults = batchResults.filter { $0.isSelected }

        for result in selectedResults {
            let updatedTask = result.task.updated(
                title: result.analysis.refinedTitle,
                notes: result.analysis.suggestedDescription,
                priority: result.analysis.suggestedPriority,
                category: result.analysis.suggestedCategory,
                customCategoryID: result.analysis.suggestedCustomCategoryID,
                estimatedDuration: TimeInterval(result.analysis.estimatedMinutes * 60)
            )
            taskService.updateTask(updatedTask)
        }

        showBatchReviewSheet = false
        batchResults = []
    }
}

// MARK: - Batch Analysis Review Sheet

struct BatchAnalysisReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var results: [BatchAnalysisResult]
    let onApply: () -> Void

    private var selectedCount: Int {
        results.filter { $0.isSelected }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(results.count) task\(results.count == 1 ? "" : "s") analyzed")
                        .font(DesignSystem.Typography.footnote)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach($results) { $result in
                        BatchAnalysisResultRow(result: $result)
                    }
                } header: {
                    HStack {
                        Text("Proposed Changes")
                        Spacer()
                        Button(selectedCount == results.count ? "Deselect All" : "Select All") {
                            let newValue = selectedCount != results.count
                            for i in results.indices {
                                results[i].isSelected = newValue
                            }
                        }
                        .font(DesignSystem.Typography.caption1)
                    }
                }
            }
            .navigationTitle("Review Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply \(selectedCount)") {
                        onApply()
                    }
                    .disabled(selectedCount == 0)
                }
            }
        }
    }
}

// MARK: - Batch Analysis Result Row

struct BatchAnalysisResultRow: View {
    @Binding var result: BatchAnalysisResult

    // Category display helpers
    private var categoryDisplayName: String {
        if let customID = result.analysis.suggestedCustomCategoryID,
           let custom = CategoryService.shared.getCategory(byID: customID) {
            return custom.displayName
        }
        return result.analysis.suggestedCategory.displayName
    }

    private var categoryDisplayIcon: String {
        if let customID = result.analysis.suggestedCustomCategoryID,
           let custom = CategoryService.shared.getCategory(byID: customID) {
            return custom.iconName
        }
        return result.analysis.suggestedCategory.iconName
    }

    private var categoryDisplayColor: Color {
        if let customID = result.analysis.suggestedCustomCategoryID,
           let custom = CategoryService.shared.getCategory(byID: customID) {
            return custom.color
        }
        return result.analysis.suggestedCategory.color
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Checkbox
            Button {
                result.isSelected.toggle()
            } label: {
                Image(systemName: result.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(result.isSelected ? Color.Lazyflow.accent : Color.Lazyflow.textTertiary)
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)

            // Task info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Original title
                Text(result.task.title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                // Refined title (if different)
                if result.hasTitleChange, let refinedTitle = result.analysis.refinedTitle {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 10))
                            .foregroundColor(Color.Lazyflow.textTertiary)
                        Text(refinedTitle)
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(Color.orange)
                            .lineLimit(1)
                    }
                }

                // Suggested changes
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Category
                    Label {
                        Text(categoryDisplayName)
                            .font(DesignSystem.Typography.caption2)
                    } icon: {
                        Image(systemName: categoryDisplayIcon)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(categoryDisplayColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(categoryDisplayColor.opacity(0.15))
                    .cornerRadius(4)

                    // Priority (if not none)
                    if result.analysis.suggestedPriority != .none {
                        Label {
                            Text(result.analysis.suggestedPriority.displayName)
                                .font(DesignSystem.Typography.caption2)
                        } icon: {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(result.analysis.suggestedPriority.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(result.analysis.suggestedPriority.color.opacity(0.15))
                        .cornerRadius(4)
                    }

                    // Duration
                    Label {
                        Text("\(result.analysis.estimatedMinutes)m")
                            .font(DesignSystem.Typography.caption2)
                    } icon: {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(Color.Lazyflow.textSecondary)
                }

                // Description preview (if any)
                if let description = result.analysis.suggestedDescription, !description.isEmpty {
                    Text(description)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textTertiary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            result.isSelected.toggle()
        }
    }
}

// MARK: - Morning Briefing Prompt Toggle

struct MorningBriefingPromptToggle: View {
    @AppStorage("morningBriefingEnabled") private var isEnabled = true

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Image(systemName: "sun.horizon")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                Text("Show Prompt on Today")
            }
        }
        .accessibilityIdentifier("Morning Briefing Prompt Toggle")
    }
}

// MARK: - Morning Briefing Notification Toggle

struct MorningBriefingNotificationToggle: View {
    @AppStorage("morningBriefingNotificationEnabled") private var isEnabled = false
    @AppStorage("morningBriefingNotificationHour") private var notificationHour = 7 // 7 AM default

    private let notificationService = NotificationService.shared

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Morning Reminder")
                    if isEnabled {
                        Text(formattedTime)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                }
            }
        }
        .onChange(of: isEnabled) { _, newValue in
            if newValue {
                notificationService.scheduleMorningBriefing(hour: notificationHour, minute: 0)
            } else {
                notificationService.cancelMorningBriefing()
            }
        }

        if isEnabled {
            Picker("Reminder Time", selection: $notificationHour) {
                ForEach(5..<12, id: \.self) { hour in
                    Text(formatHour(hour)).tag(hour)
                }
            }
            .onChange(of: notificationHour) { _, newHour in
                notificationService.scheduleMorningBriefing(hour: newHour, minute: 0)
            }
        }
    }

    private var formattedTime: String {
        formatHour(notificationHour)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

// MARK: - Daily Summary Notification Toggle

struct DailySummaryNotificationToggle: View {
    @AppStorage("dailySummaryNotificationEnabled") private var isEnabled = false
    @AppStorage("dailySummaryNotificationHour") private var notificationHour = 20 // 8 PM default
    @State private var showTimePicker = false

    private let notificationService = NotificationService.shared

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(Color.Lazyflow.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Evening Reminder")
                    if isEnabled {
                        Text(formattedTime)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                }
            }
        }
        .accessibilityIdentifier("Evening Reminder Toggle")
        .onChange(of: isEnabled) { _, newValue in
            if newValue {
                notificationService.scheduleDailySummaryReminder(hour: notificationHour, minute: 0)
            } else {
                notificationService.cancelDailySummaryReminder()
            }
        }

        if isEnabled {
            Picker("Reminder Time", selection: $notificationHour) {
                ForEach(17..<23, id: \.self) { hour in
                    Text(formatHour(hour)).tag(hour)
                }
            }
            .onChange(of: notificationHour) { _, newHour in
                notificationService.scheduleDailySummaryReminder(hour: newHour, minute: 0)
            }
        }
    }

    private var formattedTime: String {
        formatHour(notificationHour)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

// MARK: - Live Activity Toggle

struct LiveActivityToggle: View {
    @ObservedObject private var liveActivityManager = LiveActivityManager.shared
    @State private var isEnabled = false

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Image(systemName: "rectangle.badge.checkmark")
                    .foregroundColor(Color.Lazyflow.accent)
                    .frame(width: 24)
                Text("Track Today's Progress")
            }
        }
        .onChange(of: isEnabled) { _, newValue in
            _Concurrency.Task {
                if newValue {
                    await startLiveActivity()
                } else {
                    await liveActivityManager.stopTracking()
                }
            }
        }
        .onAppear {
            isEnabled = liveActivityManager.isTrackingActive
        }
    }

    private func startLiveActivity() async {
        let tasks = TaskService.shared.tasks
        let todayTasks = tasks.filter { $0.isDueToday || $0.isOverdue }
        let completedCount = todayTasks.filter { $0.isCompleted }.count
        let totalCount = todayTasks.count

        guard totalCount > 0 else { return }

        // Find in-progress task
        let inProgressTask = todayTasks.first { $0.isInProgress }

        let incompleteTasks = todayTasks.filter { !$0.isCompleted && !$0.isInProgress }
            .sorted { task1, task2 in
                if task1.priority != task2.priority {
                    return task1.priority.rawValue > task2.priority.rawValue
                }
                if let date1 = task1.dueDate, let date2 = task2.dueDate {
                    return date1 < date2
                }
                return task1.dueDate != nil
            }

        let currentTask = incompleteTasks.first
        let nextTask = incompleteTasks.dropFirst().first

        await liveActivityManager.startTracking(
            completedCount: completedCount,
            totalCount: totalCount,
            currentTask: currentTask?.title,
            currentPriority: currentTask?.priority.rawValue ?? 0,
            nextTask: nextTask?.title,
            nextPriority: nextTask?.priority.rawValue ?? 0,
            inProgressTask: inProgressTask?.title,
            inProgressStartedAt: inProgressTask?.updatedAt,
            inProgressPriority: inProgressTask?.priority.rawValue ?? 0,
            inProgressEstimatedDuration: inProgressTask?.estimatedDuration
        )
    }
}

// MARK: - Provider Configuration Sheet

struct ProviderConfigurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var llmService = LLMService.shared

    let providerType: LLMProviderType

    @State private var endpoint: String = ""
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var showDeleteConfirmation = false
    @State private var showTestConfirmation = false
    @State private var availableModels: [AvailableModel] = []
    @State private var isFetchingModels = false
    @State private var modelFetchError: String?
    @State private var hasLoadedConfig = false

    private enum TestResult {
        case success
        case failure(String)
    }

    private var isConfigured: Bool {
        llmService.availableProviders.contains(providerType)
    }

    private var canSave: Bool {
        !endpoint.isEmpty && !model.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Provider Info
                Section {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: providerType.iconName)
                            .font(.title2)
                            .foregroundColor(Color.Lazyflow.accent)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(providerType.displayName)
                                .font(DesignSystem.Typography.headline)

                            Text(providerType.description)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }
                }

                // Privacy Warning for external providers
                if providerType.isExternal {
                    Section {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color.Lazyflow.warning)
                            Text("Your task data will be sent to external servers when using this provider.")
                                .font(DesignSystem.Typography.footnote)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }
                }

                // Configuration Fields
                Section("Configuration") {
                    TextField("Endpoint URL", text: $endpoint)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: endpoint) { _, _ in
                            // Clear models when endpoint changes
                            availableModels = []
                            modelFetchError = nil
                        }

                    // Show API key field for providers that require it OR custom endpoints (optional)
                    if providerType.requiresAPIKey || providerType == .custom {
                        SecureField(providerType == .custom ? "API Key (optional)" : "API Key", text: $apiKey)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                }

                // Model Selection
                Section {
                    if availableModels.isEmpty {
                        // Manual entry with fetch button
                        HStack {
                            TextField("Model Name", text: $model)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()

                            Button {
                                fetchModels()
                            } label: {
                                if isFetchingModels {
                                    ProgressView()
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(Color.Lazyflow.accent)
                                }
                            }
                            .disabled(endpoint.isEmpty || isFetchingModels)
                        }

                        if let error = modelFetchError {
                            Text(error)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.error)
                        }
                    } else {
                        // Model selection with NavigationLink
                        NavigationLink {
                            ModelSelectionView(
                                models: availableModels,
                                selectedModelId: $model
                            )
                        } label: {
                            HStack {
                                Text("Model")
                                Spacer()
                                if let selectedModel = availableModels.first(where: { $0.id == model }) {
                                    Text(selectedModel.displayName)
                                        .foregroundColor(Color.Lazyflow.textSecondary)
                                        .lineLimit(1)
                                } else {
                                    Text("Select")
                                        .foregroundColor(Color.Lazyflow.textTertiary)
                                }
                            }
                        }

                        Button {
                            availableModels = []
                            model = ""
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Enter Manually")
                            }
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(Color.Lazyflow.accent)
                        }
                    }
                } header: {
                    Text("Model")
                } footer: {
                    if availableModels.isEmpty && providerType != .custom {
                        Text("Tap the download icon to fetch available models from the server.")
                    } else if !availableModels.isEmpty {
                        let freeCount = availableModels.filter { $0.isFree }.count
                        if freeCount > 0 && freeCount < availableModels.count {
                            Text("\(availableModels.count) models available (\(freeCount) free)")
                        } else {
                            Text("\(availableModels.count) models available")
                        }
                    }
                }

                // Test Connection
                Section {
                    Button {
                        // Show confirmation for external providers
                        if providerType.isExternal {
                            showTestConfirmation = true
                        } else {
                            testConnection()
                        }
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "network")
                            }
                            Text("Test Connection")
                            Spacer()
                            if let result = testResult {
                                switch result {
                                case .success:
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color.Lazyflow.success)
                                case .failure:
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.Lazyflow.error)
                                }
                            }
                        }
                    }
                    .disabled(!canSave || isTesting)

                    if case .failure(let message) = testResult {
                        Text(message)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.error)
                    }
                }

                // Remove Provider (if configured)
                if isConfigured {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove Provider")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Configure \(providerType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConfiguration()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                loadExistingConfig()
            }
            .alert("Remove Provider", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    llmService.removeOpenResponsesProvider(type: providerType)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to remove \(providerType.displayName)? You'll need to reconfigure it to use it again.")
            }
            .alert("Test Connection", isPresented: $showTestConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Test Anyway") {
                    testConnection()
                }
            } message: {
                Text("This will send a test request to \(providerType.displayName). Your task data may be sent to external servers.")
            }
        }
    }

    private func loadExistingConfig() {
        // Only load once to prevent resetting fields when navigating back from model selection
        guard !hasLoadedConfig else { return }
        hasLoadedConfig = true

        // Load default or existing configuration
        let config: OpenResponsesConfig

        if let existingConfig = llmService.getOpenResponsesConfig(for: providerType) {
            config = existingConfig
        } else {
            // Use defaults based on provider type
            switch providerType {
            case .ollama:
                config = .ollamaDefault
            case .custom:
                config = .customDefault
            case .apple:
                return // Apple doesn't need configuration
            }
        }

        endpoint = config.endpoint
        apiKey = config.apiKey ?? ""
        model = config.model
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        let config = OpenResponsesConfig(
            endpoint: endpoint,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            model: model
        )

        _Concurrency.Task {
            do {
                _ = try await llmService.testConnection(config: config)
                await MainActor.run {
                    testResult = .success
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }

    private func saveConfiguration() {
        let config = OpenResponsesConfig(
            endpoint: endpoint,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            model: model
        )

        llmService.configureOpenResponses(config: config, providerType: providerType)
        llmService.selectedProvider = providerType
        dismiss()
    }

    private func fetchModels() {
        isFetchingModels = true
        modelFetchError = nil

        _Concurrency.Task {
            do {
                let models = try await OpenResponsesConfig.fetchAvailableModels(
                    endpoint: endpoint,
                    apiKey: apiKey.isEmpty ? nil : apiKey,
                    for: providerType
                )

                await MainActor.run {
                    availableModels = models
                    isFetchingModels = false

                    // Auto-select first model if current model is empty or not in list
                    if model.isEmpty || !models.contains(where: { $0.id == model }) {
                        model = models.first?.id ?? ""
                    }
                }
            } catch {
                await MainActor.run {
                    modelFetchError = "Failed to fetch models: \(error.localizedDescription)"
                    isFetchingModels = false
                }
            }
        }
    }
}

// MARK: - Model Selection View

/// View for selecting a model from available models, grouped by provider
struct ModelSelectionView: View {
    let models: [AvailableModel]
    @Binding var selectedModelId: String
    @Environment(\.dismiss) private var dismiss
    @State private var showFreeOnly = false
    @State private var selectedModelForDetail: AvailableModel?
    @State private var searchText = ""

    /// Models filtered by search and free filter, grouped by provider
    private var groupedModels: [(provider: String, models: [AvailableModel])] {
        var filtered = models

        // Apply free filter
        if showFreeOnly {
            filtered = filtered.filter { $0.isFree }
        }

        // Apply search filter
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            filtered = filtered.filter {
                $0.name.lowercased().contains(search) ||
                $0.id.lowercased().contains(search) ||
                ($0.description?.lowercased().contains(search) ?? false)
            }
        }

        let grouped = Dictionary(grouping: filtered) { $0.provider ?? "Other" }
        return grouped.sorted { $0.key < $1.key }.map { (provider: $0.key, models: $0.value) }
    }

    var body: some View {
        List {
            // Free filter toggle (only show if there are both free and paid models)
            let freeCount = models.filter { $0.isFree }.count
            if freeCount > 0 && freeCount < models.count {
                Section {
                    Toggle("Show Free Models Only", isOn: $showFreeOnly)
                } footer: {
                    Text("\(freeCount) of \(models.count) models are free")
                }
            }

            // Grouped models
            ForEach(groupedModels, id: \.provider) { group in
                Section(group.provider) {
                    ForEach(group.models) { model in
                        Button {
                            selectedModelId = model.id
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(model.displayName)
                                            .foregroundColor(Color.Lazyflow.textPrimary)
                                        if model.isFree {
                                            Text("FREE")
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.Lazyflow.success)
                                                .cornerRadius(3)
                                        }
                                    }
                                    if let desc = model.description {
                                        Text(desc)
                                            .font(DesignSystem.Typography.caption2)
                                            .foregroundColor(Color.Lazyflow.textTertiary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                // Info indicator (visual hint for swipe)
                                if model.description != nil {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.Lazyflow.textTertiary.opacity(0.6))
                                }

                                // Checkmark for selected model
                                if model.id == selectedModelId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.Lazyflow.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if model.description != nil {
                                Button {
                                    selectedModelForDetail = model
                                } label: {
                                    Label("Info", systemImage: "info.circle")
                                }
                                .tint(Color.Lazyflow.accent)
                            }
                        }
                    }
                }
            }

            // Hint about swipe for details
            if models.contains(where: { $0.description != nil }) {
                Section {
                } footer: {
                    Text("Swipe left on a model for more details")
                        .font(DesignSystem.Typography.caption2)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search models")
        .navigationTitle("Select Model")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedModelForDetail) { model in
            ModelDetailSheet(model: model)
        }
    }
}

/// Sheet showing model details
struct ModelDetailSheet: View {
    let model: AvailableModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Model name
                    HStack {
                        Text(model.displayName)
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                        if model.isFree {
                            Text("FREE")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.Lazyflow.success)
                                .cornerRadius(4)
                        }
                    }

                    // Provider
                    if let provider = model.provider {
                        HStack {
                            Text("Provider:")
                                .foregroundColor(Color.Lazyflow.textSecondary)
                            Text(provider)
                        }
                        .font(DesignSystem.Typography.subheadline)
                    }

                    // Model ID
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model ID")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                        Text(model.id)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(Color.Lazyflow.textPrimary)
                    }

                    // Description
                    if let description = model.description {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                            Text(description)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(Color.Lazyflow.textPrimary)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Model Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
