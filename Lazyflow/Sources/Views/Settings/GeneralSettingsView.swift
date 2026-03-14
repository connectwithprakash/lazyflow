import SwiftUI
import LazyflowCore
import LazyflowUI

struct GeneralSettingsView: View {
    @AppStorage(AppConstants.StorageKey.appearanceMode) private var appearanceMode: AppearanceMode = .system
    @AppStorage(AppConstants.StorageKey.defaultReminderTime) private var defaultReminderTime: Int = AppConstants.Defaults.reminderHour
    @AppStorage(AppConstants.StorageKey.showCompletedTasks) private var showCompletedTasks: Bool = true
    @AppStorage(AppConstants.StorageKey.hapticFeedback) private var hapticFeedback: Bool = true

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("Tasks") {
                Toggle("Show Completed Tasks", isOn: $showCompletedTasks)

                Picker("Default Reminder Time", selection: $defaultReminderTime) {
                    ForEach(6..<22) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
            }

            Section("Accessibility") {
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
            }
        }
        .settingsFormWidth()
        .navigationTitle("General")
    }
}
