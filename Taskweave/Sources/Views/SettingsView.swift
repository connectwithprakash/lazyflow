import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("defaultReminderTime") private var defaultReminderTime: Int = 9
    @AppStorage("showCompletedTasks") private var showCompletedTasks: Bool = true
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true

    @State private var showAbout = false
    @State private var showNotificationSettings = false
    @State private var showAISettings = false

    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: No NavigationStack (provided by split view), centered form
            settingsForm
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
                .navigationTitle("Settings")
                .sheet(isPresented: $showAbout) { AboutView() }
                .sheet(isPresented: $showNotificationSettings) { NotificationSettingsView() }
                .sheet(isPresented: $showAISettings) { AISettingsView() }
        } else {
            // iPhone: Full NavigationStack
            NavigationStack {
                settingsForm
                    .navigationTitle("Settings")
                    .sheet(isPresented: $showAbout) { AboutView() }
                    .sheet(isPresented: $showNotificationSettings) { NotificationSettingsView() }
                    .sheet(isPresented: $showAISettings) { AISettingsView() }
            }
        }
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
                                .foregroundColor(Color.Taskweave.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.Taskweave.textTertiary)
                        }
                    }
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
                                .foregroundColor(Color.Taskweave.textPrimary)
                            Spacer()
                            if LLMService.shared.isReady {
                                Text(LLMService.shared.selectedProvider.displayName)
                                    .font(DesignSystem.Typography.footnote)
                                    .foregroundColor(Color.Taskweave.textSecondary)
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.Taskweave.success)
                            } else {
                                Text("Configure")
                                    .font(DesignSystem.Typography.footnote)
                                    .foregroundColor(Color.Taskweave.textSecondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.Taskweave.textTertiary)
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
                            .foregroundColor(Color.Taskweave.textSecondary)
                    }

                    Button {
                        showAbout = true
                    } label: {
                        Text("About Taskweave")
                            .foregroundColor(Color.Taskweave.textPrimary)
                    }

                    Link(destination: URL(string: "https://taskweave.netlify.app/privacy/")!) {
                        Text("Privacy Policy")
                    }

                    Link(destination: URL(string: "https://taskweave.netlify.app/terms/")!) {
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

                            Text("Enable notifications in Settings to receive task reminders. Tap Open Settings, then tap Notifications.")
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

    @State private var anthropicKeyInput: String = ""
    @State private var openaiKeyInput: String = ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var isBatchAnalyzing = false
    @State private var batchAnalysisProgress: Int = 0
    @State private var batchAnalysisTotal: Int = 0
    @State private var showBatchReviewSheet = false
    @State private var batchResults: [BatchAnalysisResult] = []

    enum ConnectionTestResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Provider Selection
                Section {
                    ForEach(llmService.availableProviders) { provider in
                        providerRow(for: provider)
                    }
                } header: {
                    Text("AI Provider")
                } footer: {
                    Text(providerFooterText)
                }

                // API Key Section (shown for non-Apple providers)
                if llmService.selectedProvider != .apple {
                    apiKeySection
                }

                // AI Features Section
                Section("AI Features") {
                    Toggle(isOn: $aiAutoSuggest) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Suggest")
                            Text("Show AI suggestions when creating tasks")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Taskweave.textSecondary)
                        }
                    }

                    Toggle(isOn: $aiEstimateDuration) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Estimate Duration")
                            Text("AI estimates how long tasks will take")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Taskweave.textSecondary)
                        }
                    }

                    Toggle(isOn: $aiSuggestPriority) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Suggest Priority")
                            Text("AI suggests task priority levels")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Taskweave.textSecondary)
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
                                    .foregroundColor(Color.Taskweave.textPrimary)
                                Text("\(uncategorizedTaskCount) tasks need categorization")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Taskweave.textSecondary)
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
                                    .foregroundColor(Color.Taskweave.textSecondary)
                                Spacer()
                                Text("\(batchAnalysisProgress)/\(batchAnalysisTotal)")
                                    .font(DesignSystem.Typography.footnote)
                                    .foregroundColor(Color.Taskweave.textSecondary)
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

                // Provider Info
                Section("About \(llmService.selectedProvider.displayName)") {
                    providerInfoContent
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

    // MARK: - Provider Row

    @ViewBuilder
    private func providerRow(for provider: LLMProviderType) -> some View {
        Button {
            withAnimation {
                llmService.selectedProvider = provider
                connectionTestResult = nil
            }
        } label: {
            HStack {
                Image(systemName: provider.iconName)
                    .foregroundColor(Color.Taskweave.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .foregroundColor(Color.Taskweave.textPrimary)
                    Text(provider.description)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Taskweave.textSecondary)
                }

                Spacer()

                if llmService.selectedProvider == provider {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.Taskweave.accent)
                } else if provider.requiresAPIKey && !llmService.hasAPIKey(for: provider) {
                    Text("Needs key")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(Color.Taskweave.textTertiary)
                }
            }
        }
    }

    // MARK: - API Key Section

    @ViewBuilder
    private var apiKeySection: some View {
        Section {
            switch llmService.selectedProvider {
            case .anthropic:
                SecureField("Anthropic API Key", text: $anthropicKeyInput)
                    .textContentType(.password)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                if llmService.hasAPIKey(for: .anthropic) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.Taskweave.success)
                        Text("API key configured")
                            .foregroundColor(Color.Taskweave.textSecondary)
                    }
                }

                saveButton(for: .anthropic, keyInput: anthropicKeyInput)

            case .openai:
                SecureField("OpenAI API Key", text: $openaiKeyInput)
                    .textContentType(.password)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                if llmService.hasAPIKey(for: .openai) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.Taskweave.success)
                        Text("API key configured")
                            .foregroundColor(Color.Taskweave.textSecondary)
                    }
                }

                saveButton(for: .openai, keyInput: openaiKeyInput)

            case .apple:
                EmptyView()
            }

            if let result = connectionTestResult {
                switch result {
                case .success:
                    Label("Connection successful", systemImage: "checkmark.circle.fill")
                        .foregroundColor(Color.Taskweave.success)
                case .failure(let message):
                    Label(message, systemImage: "xmark.circle.fill")
                        .foregroundColor(Color.Taskweave.error)
                        .font(DesignSystem.Typography.footnote)
                }
            }
        } header: {
            Text("\(llmService.selectedProvider.displayName) API")
        } footer: {
            Text(apiKeyFooterText)
        }
    }

    @ViewBuilder
    private func saveButton(for provider: LLMProviderType, keyInput: String) -> some View {
        Button {
            saveAPIKey(for: provider, key: keyInput)
        } label: {
            HStack {
                if isTestingConnection {
                    ProgressView()
                        .padding(.trailing, DesignSystem.Spacing.xs)
                }
                Text(llmService.hasAPIKey(for: provider) ? "Update API Key" : "Save API Key")
            }
        }
        .disabled(keyInput.isEmpty || isTestingConnection)
    }

    // MARK: - Provider Info

    @ViewBuilder
    private var providerInfoContent: some View {
        switch llmService.selectedProvider {
        case .apple:
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Label {
                    Text("On-Device Processing")
                        .font(DesignSystem.Typography.subheadline)
                } icon: {
                    Image(systemName: "iphone")
                        .foregroundColor(Color.Taskweave.accent)
                }
                Text("All AI processing happens on your device. Your data never leaves your phone.")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Taskweave.textSecondary)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Label {
                    Text("Free & Private")
                        .font(DesignSystem.Typography.subheadline)
                } icon: {
                    Image(systemName: "lock.shield")
                        .foregroundColor(Color.Taskweave.accent)
                }
                Text("No API key required. No usage costs. Maximum privacy.")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Taskweave.textSecondary)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)

        case .anthropic:
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Label {
                    Text("Claude 3 Haiku")
                        .font(DesignSystem.Typography.subheadline)
                } icon: {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(Color.Taskweave.accent)
                }
                Text("Fast and cost-effective model optimized for task analysis.")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Taskweave.textSecondary)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)

        case .openai:
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Label {
                    Text("GPT-4.1 Mini")
                        .font(DesignSystem.Typography.subheadline)
                } icon: {
                    Image(systemName: "globe")
                        .foregroundColor(Color.Taskweave.accent)
                }
                Text("OpenAI's fast and affordable model for everyday tasks.")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Taskweave.textSecondary)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
    }

    // MARK: - Helper Text

    private var providerFooterText: String {
        switch llmService.selectedProvider {
        case .apple:
            return "Apple Intelligence runs entirely on-device. Requires iOS 18.4 or later."
        case .anthropic:
            return "Uses Anthropic's Claude API. Requires an API key from console.anthropic.com"
        case .openai:
            return "Uses OpenAI's API. Requires an API key from platform.openai.com"
        }
    }

    private var apiKeyFooterText: String {
        switch llmService.selectedProvider {
        case .anthropic:
            return "Get your API key from console.anthropic.com. Your key is stored securely on device."
        case .openai:
            return "Get your API key from platform.openai.com. Your key is stored securely on device."
        case .apple:
            return ""
        }
    }

    // MARK: - Actions

    private func saveAPIKey(for provider: LLMProviderType, key: String) {
        guard !key.isEmpty else { return }
        isTestingConnection = true
        connectionTestResult = nil

        llmService.setAPIKey(key, for: provider)

        // Test the connection
        _Concurrency.Task {
            do {
                _ = try await llmService.estimateTaskDuration(title: "Test task", notes: nil)
                await MainActor.run {
                    connectionTestResult = .success
                    // Clear the input field
                    switch provider {
                    case .anthropic: anthropicKeyInput = ""
                    case .openai: openaiKeyInput = ""
                    case .apple: break
                    }
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = .failure(error.localizedDescription)
                    isTestingConnection = false
                }
            }
        }
    }

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
                        .foregroundColor(Color.Taskweave.textSecondary)
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

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Checkbox
            Button {
                result.isSelected.toggle()
            } label: {
                Image(systemName: result.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(result.isSelected ? Color.Taskweave.accent : Color.Taskweave.textTertiary)
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)

            // Task info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Original title
                Text(result.task.title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(Color.Taskweave.textPrimary)

                // Refined title (if different)
                if result.hasTitleChange, let refinedTitle = result.analysis.refinedTitle {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 10))
                            .foregroundColor(Color.Taskweave.textTertiary)
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
                        Text(result.analysis.suggestedCategory.displayName)
                            .font(DesignSystem.Typography.caption2)
                    } icon: {
                        Image(systemName: result.analysis.suggestedCategory.iconName)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(result.analysis.suggestedCategory.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(result.analysis.suggestedCategory.color.opacity(0.15))
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
                    .foregroundColor(Color.Taskweave.textSecondary)
                }

                // Description preview (if any)
                if let description = result.analysis.suggestedDescription, !description.isEmpty {
                    Text(description)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Taskweave.textTertiary)
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

// MARK: - Live Activity Toggle

struct LiveActivityToggle: View {
    @ObservedObject private var liveActivityManager = LiveActivityManager.shared
    @State private var isEnabled = false

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Image(systemName: "rectangle.badge.checkmark")
                    .foregroundColor(Color.Taskweave.accent)
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
