import SwiftUI

struct ReminderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasReminder: Bool
    @Binding var reminderDate: Date?
    var defaultDate: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Toggle("Set Reminder", isOn: Binding(
                        get: { hasReminder },
                        set: { newValue in
                            hasReminder = newValue
                            if newValue && reminderDate == nil {
                                reminderDate = defaultDate ?? Date()
                            }
                        }
                    ).animation())
                        .font(DesignSystem.Typography.subheadline)
                        .padding(.horizontal)

                    if hasReminder {
                        DatePicker(
                            "Remind at",
                            selection: Binding(
                                get: { reminderDate ?? Date() },
                                set: { reminderDate = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .font(DesignSystem.Typography.subheadline)
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Quick Options")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                                .padding(.horizontal)

                            HStack(spacing: DesignSystem.Spacing.sm) {
                                ReminderQuickOption(title: "Morning", time: "9:00 AM") {
                                    setReminderTime(hour: 9, minute: 0)
                                }
                                ReminderQuickOption(title: "Noon", time: "12:00 PM") {
                                    setReminderTime(hour: 12, minute: 0)
                                }
                                ReminderQuickOption(title: "Evening", time: "6:00 PM") {
                                    setReminderTime(hour: 18, minute: 0)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, DesignSystem.Spacing.lg)
            }
            .navigationTitle("Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if hasReminder {
                        Button("Clear") {
                            hasReminder = false
                            reminderDate = nil
                            dismiss()
                        }
                        .foregroundColor(Color.Lazyflow.error)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if hasReminder && reminderDate == nil {
                reminderDate = defaultDate ?? Date()
            }
        }
    }

    private func setReminderTime(hour: Int, minute: Int) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: reminderDate ?? Date())
        components.hour = hour
        components.minute = minute
        if let newDate = calendar.date(from: components) {
            reminderDate = newDate
        }
    }
}
