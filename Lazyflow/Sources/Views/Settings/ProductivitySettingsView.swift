import SwiftUI
import LazyflowCore
import LazyflowUI

struct ProductivitySettingsView: View {
    var scrollToItemID: String? = nil

    @AppStorage(AppConstants.StorageKey.pomodoroWorkMinutes) private var pomodoroWorkMinutes: Double = AppConstants.Defaults.pomodoroWorkMinutes
    @AppStorage(AppConstants.StorageKey.pomodoroBreakMinutes) private var pomodoroBreakMinutes: Double = AppConstants.Defaults.pomodoroBreakMinutes

    var body: some View {
        ScrollViewReader { proxy in
        Form {
            Section {
                CalendarSyncToggle()
            } header: {
                Text("Calendar Sync")
            } footer: {
                // swiftlint:disable:next line_length
                Text("Eligible tasks (with date, time, and duration) are auto-synced to a dedicated Lazyflow calendar. Changes made in Apple Calendar sync back to your tasks.")
            }
            .id("productivity_auto_sync")

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
            .id("productivity_auto_hide")

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
            .id("productivity_work_interval")

            Section {
                LiveActivityToggle()
            } header: {
                Text("Live Activity")
            } footer: {
                Text("Shows task progress on Lock Screen and Dynamic Island (iPhone 14+)")
            }
            .id("productivity_live_activity")
        }
        .settingsFormWidth()
        .navigationTitle("Productivity")
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
