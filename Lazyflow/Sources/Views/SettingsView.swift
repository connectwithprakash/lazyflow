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

                // Categories
                Section("Categories") {
                    NavigationLink {
                        CategoryManagementView()
                    } label: {
                        HStack {
                            Label("Manage Categories", systemImage: "tag")
                                .foregroundColor(Color.Lazyflow.textPrimary)
                            Spacer()
                            Text("\(CategoryService.shared.categories.count) custom")
                                .font(DesignSystem.Typography.footnote)
                                .foregroundColor(Color.Lazyflow.textSecondary)
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

                // Morning Briefing Notifications
                Section {
                    MorningBriefingNotificationToggle()
                } header: {
                    Text("Morning Briefing")
                } footer: {
                    Text("Get a notification to view your morning briefing. Access it anytime from More > Morning Briefing.")
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

    var body: some View {
        NavigationStack {
            Form {
                // Apple Intelligence Info
                Section {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "apple.logo")
                            .font(.title2)
                            .foregroundColor(Color.Lazyflow.accent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Intelligence")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(Color.Lazyflow.textPrimary)

                            Text("On-device • Private • Free")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }

                        Spacer()

                        if llmService.isReady {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.Lazyflow.success)
                        } else {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Color.Lazyflow.warning)
                        }
                    }
                } header: {
                    Text("AI Provider")
                } footer: {
                    Text("AI features are powered by Apple Intelligence, running entirely on your device. No data leaves your device. Requires iOS 18.4 or later.")
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

// MARK: - Preview

#Preview {
    SettingsView()
}
