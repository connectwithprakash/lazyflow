import SwiftUI
import LazyflowCore
import LazyflowUI

struct TimeBlockSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedDate: Date?
    @Binding var hasDate: Bool
    @Binding var selectedTime: Date?
    @Binding var hasTime: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Quick Time Chips

                HStack(spacing: DesignSystem.Spacing.sm) {
                    TimeQuickOption(title: "Morning", hour: 9) {
                        setTime(hour: 9, minute: 0)
                    }
                    TimeQuickOption(title: "Afternoon", hour: 13) {
                        setTime(hour: 13, minute: 0)
                    }
                    TimeQuickOption(title: "Evening", hour: 18) {
                        setTime(hour: 18, minute: 0)
                    }
                }
                .padding(.horizontal)
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.xs)

                // MARK: - Time Wheel

                DatePicker(
                    "Start Time",
                    selection: Binding(
                        get: { selectedTime ?? nextQuarterHour() },
                        set: {
                            selectedTime = $0
                            hasTime = true
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.horizontal)
            }
            .navigationTitle("Start Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if hasTime {
                        Button("Clear") {
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
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                if !hasDate {
                    selectedDate = Date()
                    hasDate = true
                }
                if selectedTime == nil {
                    selectedTime = nextQuarterHour()
                    hasTime = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func nextQuarterHour() -> Date {
        let cal = Calendar.current
        let now = Date()
        let minute = cal.component(.minute, from: now)
        let roundedUp = ((minute / 15) + 1) * 15
        return cal.date(byAdding: .minute, value: roundedUp - minute, to: now) ?? now
    }

    private func setTime(hour: Int, minute: Int) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        if let date = Calendar.current.date(from: components) {
            selectedTime = date
            hasTime = true
        }
    }
}

// MARK: - Time Quick Option

private struct TimeQuickOption: View {
    let title: String
    let hour: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                Text(formattedHour)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var formattedHour: String {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        guard let date = Calendar.current.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }
}
