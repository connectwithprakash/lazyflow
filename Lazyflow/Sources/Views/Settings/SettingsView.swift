import SwiftUI
import os
import LazyflowCore
import LazyflowUI

/// Settings view for app configuration
struct SettingsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppConstants.StorageKey.appearanceMode) private var appearanceMode: AppearanceMode = .system
    @AppStorage(AppConstants.StorageKey.defaultReminderTime) private var defaultReminderTime: Int = AppConstants.Defaults.reminderHour
    @AppStorage(AppConstants.StorageKey.showCompletedTasks) private var showCompletedTasks: Bool = true
    @AppStorage(AppConstants.StorageKey.hapticFeedback) private var hapticFeedback: Bool = true
    @AppStorage(AppConstants.StorageKey.summaryPromptHour) private var summaryPromptHour: Int = AppConstants.Defaults.summaryPromptHour
    @AppStorage(AppConstants.StorageKey.pomodoroWorkMinutes) private var pomodoroWorkMinutes: Double = AppConstants.Defaults.pomodoroWorkMinutes
    @AppStorage(AppConstants.StorageKey.pomodoroBreakMinutes) private var pomodoroBreakMinutes: Double = AppConstants.Defaults.pomodoroBreakMinutes

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
                    .accessibilityLabel("Notification Settings")
                    .accessibilityHint("Configure task reminder notifications")
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
                        get: { UserDefaults.standard.bool(forKey: AppConstants.StorageKey.autoHideSkippedEvents) },
                        set: { UserDefaults.standard.set($0, forKey: AppConstants.StorageKey.autoHideSkippedEvents) }
                    ))
                } header: {
                    Text("Plan Your Day")
                } footer: {
                    Text("Events you consistently skip will be hidden by default. You can always reveal them.")
                }

                // Calendar Sync
                Section {
                    CalendarSyncToggle()
                } header: {
                    Text("Calendar Sync")
                } footer: {
                    Text("Eligible tasks (with date, time, and duration) are auto-synced to a dedicated Lazyflow calendar. Changes made in Apple Calendar sync back to your tasks.")
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

                // Focus Mode
                Section("Focus Mode") {
                    Stepper(
                        "Work Interval: \(Int(pomodoroWorkMinutes)) min",
                        value: $pomodoroWorkMinutes,
                        in: 5...60,
                        step: 5
                    )
                    Stepper(
                        "Break Interval: \(Int(pomodoroBreakMinutes)) min",
                        value: $pomodoroBreakMinutes,
                        in: 1...30,
                        step: 1
                    )
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
                    .accessibilityLabel("AI Settings\(LLMService.shared.isReady ? ", \(LLMService.shared.selectedProvider.displayName) configured" : ", not configured")")
                    .accessibilityHint("Configure AI provider and features")
                }

                // Data
                Section("Data") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Text("Data Management")
                    }
                }

                // Developer (debug builds only)
                #if DEBUG
                Section("Developer") {
                    NavigationLink {
                        FeatureFlagsDebugView()
                    } label: {
                        Label("Feature Flags", systemImage: "flag")
                    }
                }
                #endif

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

// MARK: - Preview

#Preview {
    SettingsView()
}
