import SwiftUI

extension AddTaskView {

    // MARK: - Quick Actions Grid (3-row layout)

    var quickActionsGrid: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Row 1: Date options
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Due Date picker
                QuickActionButton(
                    icon: "calendar",
                    title: dateButtonTitle,
                    isSelected: addTaskViewModel.hasDueDate,
                    color: Color.Lazyflow.accent
                ) {
                    showDatePicker = true
                }

                // Today quick action
                QuickActionButton(
                    icon: "star",
                    title: "Today",
                    isSelected: addTaskViewModel.dueDate?.isToday == true,
                    color: Color.Lazyflow.warning
                ) {
                    addTaskViewModel.setDueToday()
                }

                // Tomorrow quick action
                QuickActionButton(
                    icon: "sunrise",
                    title: "Tomorrow",
                    isSelected: addTaskViewModel.dueDate?.isTomorrow == true,
                    color: Color.Lazyflow.priorityMedium
                ) {
                    addTaskViewModel.setDueTomorrow()
                }
            }

            // Row 2: Priority, Category, List
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Priority
                Menu {
                    ForEach(Priority.allCases) { priority in
                        Button {
                            addTaskViewModel.priority = priority
                        } label: {
                            Label(priority.displayName, systemImage: priority.iconName)
                        }
                    }
                } label: {
                    QuickActionButtonContent(
                        icon: addTaskViewModel.priority.iconName,
                        title: addTaskViewModel.priority == .none ? "Priority" : addTaskViewModel.priority.displayName,
                        isSelected: addTaskViewModel.priority != .none,
                        color: addTaskViewModel.priority.color
                    )
                }

                // Category
                Menu {
                    // System categories
                    ForEach(TaskCategory.allCases) { category in
                        Button {
                            addTaskViewModel.selectSystemCategory(category)
                        } label: {
                            Label(category.displayName, systemImage: category.iconName)
                        }
                    }

                    // Custom categories (if any)
                    if !addTaskCategoryService.categories.isEmpty {
                        Divider()

                        ForEach(addTaskCategoryService.categories) { customCategory in
                            Button {
                                addTaskViewModel.selectCustomCategory(customCategory.id)
                            } label: {
                                Label(customCategory.displayName, systemImage: customCategory.iconName)
                            }
                        }
                    }
                } label: {
                    QuickActionButtonContent(
                        icon: categoryDisplayIcon,
                        title: categoryDisplayName,
                        isSelected: addTaskViewModel.hasCategorySelected,
                        color: categoryDisplayColor
                    )
                }

                // List
                QuickActionButton(
                    icon: "folder",
                    title: selectedListName,
                    isSelected: addTaskViewModel.selectedListID != nil,
                    color: Color.Lazyflow.textTertiary
                ) {
                    showListPicker = true
                }
            }

            // Row 3: Reminder, Duration, Repeat
            HStack(spacing: DesignSystem.Spacing.sm) {
                QuickActionButton(
                    icon: addTaskViewModel.hasReminder ? "bell.fill" : "bell",
                    title: addTaskViewModel.hasReminder ? formatReminderTime(addTaskViewModel.reminderDate) : "Remind",
                    isSelected: addTaskViewModel.hasReminder,
                    color: Color.Lazyflow.info
                ) {
                    showReminderSheet = true
                }

                QuickActionButton(
                    icon: "clock",
                    title: addTaskViewModel.estimatedDuration != nil ? formatDuration(addTaskViewModel.estimatedDuration!) : "Duration",
                    isSelected: addTaskViewModel.estimatedDuration != nil,
                    color: Color.Lazyflow.accent
                ) {
                    showDurationSheet = true
                }

                QuickActionButton(
                    icon: "repeat",
                    title: addTaskViewModel.isRecurring ? recurringDisplayTitle : "Repeat",
                    isSelected: addTaskViewModel.isRecurring,
                    color: Color.Lazyflow.info
                ) {
                    showRecurringSheet = true
                }
            }
        }
    }

    // MARK: - Subtasks Section

    var subtasksSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header with add button
            HStack {
                Label("Subtasks", systemImage: "list.bullet.indent")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)

                Spacer()

                if !showAddSubtaskField {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAddSubtaskField = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.Lazyflow.accent)
                    }
                    .accessibilityLabel("Add subtask")
                }
            }

            // Add subtask field
            if showAddSubtaskField {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    TextField("Add subtask", text: $newSubtaskTitle)
                        .font(DesignSystem.Typography.body)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            addSubtask()
                        }

                    Button {
                        addSubtask()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(newSubtaskTitle.isEmpty ? Color.Lazyflow.textTertiary : Color.Lazyflow.accent)
                    }
                    .disabled(newSubtaskTitle.isEmpty)
                    .accessibilityLabel("Confirm subtask")

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAddSubtaskField = false
                            newSubtaskTitle = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.Lazyflow.textTertiary)
                    }
                    .accessibilityLabel("Cancel adding subtask")
                }
                .padding(DesignSystem.Spacing.sm)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.small)
            }

            // List of pending subtasks
            if !pendingSubtasks.isEmpty {
                VStack(spacing: 4) {
                    ForEach(pendingSubtasks, id: \.self) { subtask in
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "circle")
                                .font(.system(size: 14))
                                .foregroundColor(Color.Lazyflow.textTertiary)

                            Text(subtask)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(Color.Lazyflow.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    pendingSubtasks.removeAll { $0 == subtask }
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.Lazyflow.textTertiary)
                            }
                            .accessibilityLabel("Remove \(subtask)")
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }

    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            pendingSubtasks.append(trimmed)
            newSubtaskTitle = ""
        }
    }

    // MARK: - Selected Options View

    var selectedOptionsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if addTaskViewModel.hasDueDate, let date = addTaskViewModel.dueDate {
                    SelectedOptionChip(
                        icon: "calendar",
                        title: dateChipTitle(date: date),
                        color: date.isPast ? Color.Lazyflow.error : Color.Lazyflow.accent,
                        onRemove: { addTaskViewModel.clearDueDate() }
                    )
                }

                if addTaskViewModel.priority != .none {
                    SelectedOptionChip(
                        icon: addTaskViewModel.priority.iconName,
                        title: addTaskViewModel.priority.displayName,
                        color: addTaskViewModel.priority.color,
                        onRemove: { addTaskViewModel.priority = .none }
                    )
                }

                if addTaskViewModel.hasCategorySelected {
                    SelectedOptionChip(
                        icon: categoryDisplayIcon,
                        title: categoryDisplayName,
                        color: categoryDisplayColor,
                        onRemove: { addTaskViewModel.clearCategory() }
                    )
                }

                if let duration = addTaskViewModel.estimatedDuration {
                    SelectedOptionChip(
                        icon: "clock",
                        title: formatDuration(duration),
                        color: Color.Lazyflow.accent,
                        onRemove: { addTaskViewModel.estimatedDuration = nil }
                    )
                }

                if addTaskViewModel.hasReminder {
                    SelectedOptionChip(
                        icon: "bell.fill",
                        title: formatReminderTime(addTaskViewModel.reminderDate),
                        color: Color.Lazyflow.info,
                        onRemove: { addTaskViewModel.hasReminder = false }
                    )
                }

                if addTaskViewModel.isRecurring {
                    SelectedOptionChip(
                        icon: "repeat",
                        title: recurringDisplayTitle,
                        color: Color.Lazyflow.info,
                        onRemove: { addTaskViewModel.isRecurring = false }
                    )
                }

                if !pendingSubtasks.isEmpty {
                    SelectedOptionChip(
                        icon: "list.bullet",
                        title: "\(pendingSubtasks.count) subtask\(pendingSubtasks.count == 1 ? "" : "s")",
                        color: Color.Lazyflow.accent,
                        onRemove: { pendingSubtasks.removeAll() }
                    )
                }
            }
        }
    }
}
