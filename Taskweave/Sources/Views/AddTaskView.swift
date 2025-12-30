import SwiftUI

/// View for creating a new task
struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TaskViewModel
    @StateObject private var listService = TaskListService()
    @FocusState private var isTitleFocused: Bool

    @State private var showDatePicker = false
    @State private var showPriorityPicker = false
    @State private var showListPicker = false

    init(defaultDueDate: Date? = nil, defaultListID: UUID? = nil) {
        let vm = TaskViewModel()
        if let date = defaultDueDate {
            vm.hasDueDate = true
            vm.dueDate = date
        }
        if let listID = defaultListID {
            vm.selectedListID = listID
        }
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main input area
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Title field
                    TextField("What do you need to do?", text: $viewModel.title, axis: .vertical)
                        .font(DesignSystem.Typography.title3)
                        .focused($isTitleFocused)
                        .lineLimit(1...3)
                        .padding(.horizontal)
                        .padding(.top)

                    // Notes field
                    TextField("Add notes", text: $viewModel.notes, axis: .vertical)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(Color.Taskweave.textSecondary)
                        .lineLimit(1...4)
                        .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Quick action buttons
                    quickActionsBar
                        .padding(.horizontal)

                    // Selected options display
                    if hasSelectedOptions {
                        selectedOptionsView
                            .padding(.horizontal)
                    }
                }
                .background(Color.adaptiveSurface)

                Spacer()
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        _ = viewModel.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid)
                }
            }
            .onAppear {
                isTitleFocused = true
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(
                    selectedDate: $viewModel.dueDate,
                    hasDate: $viewModel.hasDueDate,
                    selectedTime: $viewModel.dueTime,
                    hasTime: $viewModel.hasDueTime
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showListPicker) {
                ListPickerSheet(
                    selectedListID: $viewModel.selectedListID,
                    lists: listService.lists
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Quick Actions Bar

    private var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Due Date
                QuickActionButton(
                    icon: "calendar",
                    title: viewModel.hasDueDate ? (viewModel.dueDate?.relativeFormatted ?? "Date") : "Date",
                    isSelected: viewModel.hasDueDate,
                    color: Color.Taskweave.accent
                ) {
                    showDatePicker = true
                }

                // Quick date options
                QuickActionButton(
                    icon: "star",
                    title: "Today",
                    isSelected: viewModel.dueDate?.isToday == true,
                    color: Color.Taskweave.warning
                ) {
                    viewModel.setDueToday()
                }

                QuickActionButton(
                    icon: "sunrise",
                    title: "Tomorrow",
                    isSelected: viewModel.dueDate?.isTomorrow == true,
                    color: Color.Taskweave.priorityMedium
                ) {
                    viewModel.setDueTomorrow()
                }

                // Priority
                Menu {
                    ForEach(Priority.allCases) { priority in
                        Button {
                            viewModel.priority = priority
                        } label: {
                            Label(priority.displayName, systemImage: priority.iconName)
                        }
                    }
                } label: {
                    QuickActionButtonContent(
                        icon: viewModel.priority.iconName,
                        title: viewModel.priority == .none ? "Priority" : viewModel.priority.displayName,
                        isSelected: viewModel.priority != .none,
                        color: viewModel.priority.color
                    )
                }

                // List
                QuickActionButton(
                    icon: "folder",
                    title: selectedListName,
                    isSelected: viewModel.selectedListID != nil,
                    color: Color.Taskweave.textTertiary
                ) {
                    showListPicker = true
                }

                // Reminder
                QuickActionButton(
                    icon: "bell",
                    title: viewModel.hasReminder ? "Reminder" : "Remind",
                    isSelected: viewModel.hasReminder,
                    color: Color.Taskweave.info
                ) {
                    viewModel.hasReminder.toggle()
                    if viewModel.hasReminder {
                        viewModel.reminderDate = viewModel.dueDate ?? Date()
                    }
                }
            }
        }
    }

    private var selectedListName: String {
        if let listID = viewModel.selectedListID,
           let list = listService.lists.first(where: { $0.id == listID }) {
            return list.name
        }
        return "List"
    }

    // MARK: - Selected Options

    private var hasSelectedOptions: Bool {
        viewModel.hasDueDate || viewModel.priority != .none || viewModel.hasReminder
    }

    private var selectedOptionsView: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if viewModel.hasDueDate, let date = viewModel.dueDate {
                SelectedOptionChip(
                    icon: "calendar",
                    title: date.relativeFormatted,
                    color: date.isPast ? Color.Taskweave.error : Color.Taskweave.accent,
                    onRemove: { viewModel.clearDueDate() }
                )
            }

            if viewModel.priority != .none {
                SelectedOptionChip(
                    icon: viewModel.priority.iconName,
                    title: viewModel.priority.displayName,
                    color: viewModel.priority.color,
                    onRemove: { viewModel.priority = .none }
                )
            }

            if viewModel.hasReminder {
                SelectedOptionChip(
                    icon: "bell.fill",
                    title: "Reminder",
                    color: Color.Taskweave.info,
                    onRemove: { viewModel.hasReminder = false }
                )
            }

            Spacer()
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuickActionButtonContent(icon: icon, title: title, isSelected: isSelected, color: color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickActionButtonContent: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(title)
                .font(DesignSystem.Typography.subheadline)
        }
        .foregroundColor(isSelected ? color : Color.Taskweave.textSecondary)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            isSelected
                ? color.opacity(0.15)
                : Color.secondary.opacity(0.1)
        )
        .cornerRadius(DesignSystem.CornerRadius.full)
    }
}

// MARK: - Selected Option Chip

struct SelectedOptionChip: View {
    let icon: String
    let title: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(title)
                .font(DesignSystem.Typography.caption1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(DesignSystem.CornerRadius.full)
    }
}

// MARK: - Date Picker Sheet

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
                Toggle("Add Time", isOn: $hasTime)
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
                        .foregroundColor(Color.Taskweave.error)
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
                    .foregroundColor(Color.Taskweave.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - List Picker Sheet

struct ListPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedListID: UUID?
    let lists: [TaskList]

    var body: some View {
        NavigationStack {
            List {
                ForEach(lists) { list in
                    Button {
                        selectedListID = list.id
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: list.icon)
                                .foregroundColor(list.color)
                                .frame(width: 28)

                            Text(list.name)
                                .foregroundColor(Color.Taskweave.textPrimary)

                            Spacer()

                            if selectedListID == list.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.Taskweave.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AddTaskView()
}
