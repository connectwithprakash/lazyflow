import SwiftUI
import LazyflowCore
import LazyflowUI

struct GeneralSettingsView: View {
    var scrollToItemID: String? = nil

    @AppStorage(AppConstants.StorageKey.appearanceMode) private var appearanceMode: AppearanceMode = .system
    @AppStorage(AppConstants.StorageKey.defaultReminderTime) private var defaultReminderTime: Int = AppConstants.Defaults.reminderHour
    @AppStorage(AppConstants.StorageKey.showCompletedTasks) private var showCompletedTasks: Bool = true
    @AppStorage(AppConstants.StorageKey.hapticFeedback) private var hapticFeedback: Bool = true

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }
                .id("general_theme")

                Section("Tasks") {
                    Toggle("Show Completed Tasks", isOn: $showCompletedTasks)

                    Picker("Default Reminder Time", selection: $defaultReminderTime) {
                        ForEach(6..<22) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                }
                .id("general_show_completed")

                Section("Accessibility") {
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                }
                .id("general_haptic")
            }
            .settingsFormWidth()
            .navigationTitle("General")
            .onAppear {
                if let itemID = scrollToItemID {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { proxy.scrollTo(itemID, anchor: .center) }
                    }
                }
            }
        }
    }
}
