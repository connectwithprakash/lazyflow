import SwiftUI
import LazyflowCore
import LazyflowUI

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date?
    @Binding var hasDate: Bool
    @Binding var selectedTime: Date?
    @Binding var hasTime: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Quick options
                HStack(spacing: DesignSystem.Spacing.md) {
                    DateQuickOption(title: "Today", date: Date()) {
                        selectedDate = Date()
                        hasDate = true
                    }
                    DateQuickOption(title: "Tomorrow", date: Date().addingDays(1)) {
                        selectedDate = Date().addingDays(1)
                        hasDate = true
                    }
                    DateQuickOption(title: "Next Week", date: Date().addingDays(7)) {
                        selectedDate = Date().addingDays(7)
                        hasDate = true
                    }
                }
                .padding(.horizontal)

                Divider()

                // Date picker
                DatePicker(
                    "Select Date",
                    selection: Binding(
                        get: { selectedDate ?? Date() },
                        set: {
                            selectedDate = $0
                            hasDate = true
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                // Time toggle
                Toggle("Add Time", isOn: Binding(
                    get: { hasTime },
                    set: { newValue in
                        hasTime = newValue
                        if newValue && !hasDate {
                            hasDate = true
                            if selectedDate == nil {
                                selectedDate = Date()
                            }
                        }
                    }
                ))
                    .padding(.horizontal)

                if hasTime {
                    DatePicker(
                        "Time",
                        selection: Binding(
                            get: { selectedTime ?? Date() },
                            set: { selectedTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if hasDate {
                        Button("Clear") {
                            selectedDate = nil
                            hasDate = false
                            selectedTime = nil
                            hasTime = false
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
    }
}

struct DateQuickOption: View {
    let title: String
    let date: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                Text(date.shortFormatted)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
