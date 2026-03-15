import SwiftUI
import LazyflowCore
import LazyflowUI

struct BriefingsSettingsView: View {
    var scrollToItemID: String? = nil

    @AppStorage(AppConstants.StorageKey.summaryPromptHour) private var summaryPromptHour: Int = AppConstants.Defaults.summaryPromptHour
    @State private var notificationsEnabled = false
    @State private var isCheckingPermission = true

    var body: some View {
        ScrollViewReader { proxy in
        Form {
            Section {
                MorningBriefingPromptToggle()
                MorningBriefingNotificationToggle()
            } header: {
                Text("Morning Briefing")
            } footer: {
                Text("Get a prompt card on Today and optional notification to view your morning briefing. Access it anytime from More > Morning Briefing.")
            }
            .id("notifications_morning_prompt")

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
            .id("notifications_evening_reminder")

            Section("Notifications") {
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
            .id("notifications_permission")
        }
        .settingsFormWidth()
        .navigationTitle("Notifications")
        .task {
            await checkNotificationPermission()
        }
        .onAppear {
            if let itemID = scrollToItemID {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { proxy.scrollTo(itemID, anchor: .center) }
                }
            }
        }
        }
    }

    private func checkNotificationPermission() async {
        var status = await NotificationService.shared.checkPermissionStatus()

        if status == .notDetermined {
            let granted = await NotificationService.shared.requestPermission()
            status = granted ? .authorized : .denied
        }

        notificationsEnabled = status == .authorized || status == .provisional || status == .ephemeral
        isCheckingPermission = false
    }
}
