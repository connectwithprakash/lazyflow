import SwiftUI
import LazyflowCore
import LazyflowUI

struct BriefingsSettingsView: View {
    @AppStorage(AppConstants.StorageKey.summaryPromptHour) private var summaryPromptHour: Int = AppConstants.Defaults.summaryPromptHour
    @State private var showNotificationSettings = false

    var body: some View {
        Form {
            Section {
                MorningBriefingPromptToggle()
                MorningBriefingNotificationToggle()
            } header: {
                Text("Morning Briefing")
            } footer: {
                Text("Get a prompt card on Today and optional notification to view your morning briefing. Access it anytime from More > Morning Briefing.")
            }

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
        }
        .settingsFormWidth()
        .navigationTitle("Notifications")
        .sheet(isPresented: $showNotificationSettings) { NotificationSettingsView() }
    }
}
