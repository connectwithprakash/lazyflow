import SwiftUI

struct RecurringOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    // Toggle
                    Toggle("Repeat this task", isOn: $viewModel.isRecurring.animation())
                        .font(DesignSystem.Typography.subheadline)

                    if viewModel.isRecurring {
                        // Frequency picker
                        HStack {
                            Text("Frequency")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(Color.Lazyflow.textSecondary)

                            Spacer()

                            Picker("Frequency", selection: $viewModel.recurringFrequency) {
                                ForEach(viewModel.availableFrequencies) { frequency in
                                    Text(frequency.displayName).tag(frequency)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Custom interval (for custom frequency)
                        if viewModel.recurringFrequency == .custom {
                            Stepper(
                                "Every \(viewModel.recurringInterval) day\(viewModel.recurringInterval == 1 ? "" : "s")",
                                value: $viewModel.recurringInterval,
                                in: 1...365
                            )
                            .font(DesignSystem.Typography.subheadline)
                        }

                        // Weekday picker (for weekly frequency)
                        if viewModel.recurringFrequency == .weekly {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("On days")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textSecondary)

                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    ForEach(1...7, id: \.self) { day in
                                        WeekdayButton(
                                            day: day,
                                            isSelected: viewModel.recurringDaysOfWeek.contains(day),
                                            action: {
                                                if viewModel.recurringDaysOfWeek.contains(day) {
                                                    viewModel.recurringDaysOfWeek.removeAll { $0 == day }
                                                } else {
                                                    viewModel.recurringDaysOfWeek.append(day)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }

                        // Hourly options
                        if viewModel.recurringFrequency == .hourly {
                            hourlyOptionsView
                        }

                        // Times per day options
                        if viewModel.recurringFrequency == .timesPerDay {
                            timesPerDayOptionsView
                        }

                        // Active hours (for intraday frequencies)
                        if viewModel.recurringFrequency == .hourly || viewModel.recurringFrequency == .timesPerDay {
                            activeHoursView
                        }

                        // End date
                        Toggle("End Date", isOn: Binding(
                            get: { viewModel.recurringEndDate != nil },
                            set: { newValue in
                                if newValue {
                                    viewModel.recurringEndDate = Date().addingDays(30)
                                } else {
                                    viewModel.recurringEndDate = nil
                                }
                            }
                        ))
                        .font(DesignSystem.Typography.subheadline)

                        if viewModel.recurringEndDate != nil {
                            DatePicker(
                                "Ends on",
                                selection: Binding(
                                    get: { viewModel.recurringEndDate ?? Date() },
                                    set: { viewModel.recurringEndDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .font(DesignSystem.Typography.subheadline)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
            .navigationTitle("Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.isRecurring {
                        Button("Clear") {
                            viewModel.isRecurring = false
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

    // MARK: - Hourly Options View

    private var hourlyOptionsView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Repeat Interval")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textSecondary)

            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("Every")
                    .font(DesignSystem.Typography.subheadline)

                Picker("Hours", selection: $viewModel.hourInterval) {
                    ForEach(1...12, id: \.self) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 60)

                Text("hour\(viewModel.hourInterval == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.subheadline)

                Spacer()
            }

            Text("e.g., \"Drink water\", \"Take a break\"")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(Color.Lazyflow.textTertiary)
        }
    }

    // MARK: - Times Per Day Options View

    private var timesPerDayOptionsView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Picker("Times", selection: $viewModel.timesPerDay) {
                    ForEach(2...12, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 60)

                Text("times per day")
                    .font(DesignSystem.Typography.subheadline)

                Spacer()
            }

            // Toggle for specific times vs auto-distribute
            Toggle("Set specific times", isOn: $viewModel.useSpecificTimes.animation())
                .font(DesignSystem.Typography.subheadline)

            if viewModel.useSpecificTimes {
                specificTimesEditor
            } else {
                Text("Reminders will be evenly distributed during active hours")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
        }
    }

    // MARK: - Specific Times Editor

    private var specificTimesEditor: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(0..<viewModel.timesPerDay, id: \.self) { index in
                HStack {
                    Text("Time \(index + 1)")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                        .frame(width: 60, alignment: .leading)

                    DatePicker(
                        "",
                        selection: specificTimeBinding(for: index),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
            }
        }
        .padding(.top, DesignSystem.Spacing.xs)
    }

    // MARK: - Active Hours View

    private var activeHoursView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Active Hours")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textSecondary)

            HStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("From")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(Color.Lazyflow.textTertiary)

                    DatePicker(
                        "",
                        selection: $viewModel.activeHoursStart,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("To")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(Color.Lazyflow.textTertiary)

                    DatePicker(
                        "",
                        selection: $viewModel.activeHoursEnd,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                Spacer()
            }

            Text("Reminders only during these hours")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(Color.Lazyflow.textTertiary)
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }

    // MARK: - Specific Time Binding Helper

    private func specificTimeBinding(for index: Int) -> Binding<Date> {
        Binding(
            get: {
                if index < viewModel.specificTimes.count {
                    return viewModel.specificTimes[index]
                }
                let calendar = Calendar.current
                var components = DateComponents()
                components.hour = 8 + (index * (12 / max(viewModel.timesPerDay, 1)))
                components.minute = 0
                return calendar.date(from: components) ?? Date()
            },
            set: { newValue in
                while viewModel.specificTimes.count <= index {
                    let calendar = Calendar.current
                    var components = DateComponents()
                    let nextIndex = viewModel.specificTimes.count
                    components.hour = 8 + (nextIndex * (12 / max(viewModel.timesPerDay, 1)))
                    components.minute = 0
                    viewModel.specificTimes.append(calendar.date(from: components) ?? Date())
                }
                viewModel.specificTimes[index] = newValue
            }
        )
    }
}
