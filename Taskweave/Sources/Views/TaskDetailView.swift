import SwiftUI

/// Detail view for viewing and editing a task
struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TaskViewModel
    @FocusState private var isTitleFocused: Bool

    init(task: Task) {
        _viewModel = StateObject(wrappedValue: TaskViewModel(task: task))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title & Notes
                Section {
                    TextField("Task title", text: $viewModel.title)
                        .font(DesignSystem.Typography.headline)
                        .focused($isTitleFocused)

                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                        .font(DesignSystem.Typography.body)
                        .lineLimit(3...6)
                }

                // Due Date & Time
                Section {
                    Toggle("Due Date", isOn: $viewModel.hasDueDate.animation())

                    if viewModel.hasDueDate {
                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { viewModel.dueDate ?? Date() },
                                set: { viewModel.dueDate = $0 }
                            ),
                            displayedComponents: .date
                        )

                        Toggle("Due Time", isOn: $viewModel.hasDueTime.animation())

                        if viewModel.hasDueTime {
                            DatePicker(
                                "Time",
                                selection: Binding(
                                    get: { viewModel.dueTime ?? Date() },
                                    set: { viewModel.dueTime = $0 }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }
                }

                // Reminder
                Section {
                    Toggle("Reminder", isOn: $viewModel.hasReminder.animation())

                    if viewModel.hasReminder {
                        DatePicker(
                            "Remind at",
                            selection: Binding(
                                get: { viewModel.reminderDate ?? Date() },
                                set: { viewModel.reminderDate = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                // Priority
                Section {
                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(Priority.allCases) { priority in
                            Label(priority.displayName, systemImage: priority.iconName)
                                .foregroundColor(priority.color)
                                .tag(priority)
                        }
                    }
                }

                // Duration
                Section("Estimated Duration") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(TaskViewModel.durationPresets, id: \.0) { preset in
                                DurationChip(
                                    title: preset.0,
                                    isSelected: viewModel.estimatedDuration == preset.1,
                                    action: {
                                        if viewModel.estimatedDuration == preset.1 {
                                            viewModel.estimatedDuration = nil
                                        } else {
                                            viewModel.estimatedDuration = preset.1
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    }
                }

                // Recurring
                Section {
                    Toggle("Repeat", isOn: $viewModel.isRecurring.animation())

                    if viewModel.isRecurring {
                        Picker("Frequency", selection: $viewModel.recurringFrequency) {
                            ForEach(RecurringFrequency.allCases) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }

                        if viewModel.recurringFrequency == .custom {
                            Stepper(
                                "Every \(viewModel.recurringInterval) day\(viewModel.recurringInterval == 1 ? "" : "s")",
                                value: $viewModel.recurringInterval,
                                in: 1...365
                            )
                        }

                        if viewModel.recurringFrequency == .weekly {
                            weekdayPicker
                        }

                        Toggle("End Date", isOn: Binding(
                            get: { viewModel.recurringEndDate != nil },
                            set: { if !$0 { viewModel.recurringEndDate = nil } else { viewModel.recurringEndDate = Date().addingDays(30) } }
                        ))

                        if viewModel.recurringEndDate != nil {
                            DatePicker(
                                "Ends on",
                                selection: Binding(
                                    get: { viewModel.recurringEndDate ?? Date() },
                                    set: { viewModel.recurringEndDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                        }
                    }
                }

                // Delete
                Section {
                    Button(role: .destructive) {
                        viewModel.delete()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Task")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        _ = viewModel.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }

    // MARK: - Weekday Picker

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("On days")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Taskweave.textSecondary)

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
}

// MARK: - Duration Chip

struct DurationChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(isSelected ? .white : Color.Taskweave.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    isSelected
                        ? Color.Taskweave.accent
                        : Color.secondary.opacity(0.1)
                )
                .cornerRadius(DesignSystem.CornerRadius.full)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Weekday Button

struct WeekdayButton: View {
    let day: Int
    let isSelected: Bool
    let action: () -> Void

    private var dayLetter: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        return symbols[day - 1]
    }

    var body: some View {
        Button(action: action) {
            Text(dayLetter)
                .font(DesignSystem.Typography.caption1)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : Color.Taskweave.textPrimary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? Color.Taskweave.accent : Color.secondary.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    TaskDetailView(task: Task.sample)
}
