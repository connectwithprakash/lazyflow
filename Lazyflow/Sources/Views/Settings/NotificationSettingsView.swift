import SwiftUI
import LazyflowCore
import LazyflowUI

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
