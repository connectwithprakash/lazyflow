import SwiftUI

/// Detail view showing tasks for a specific list
struct ListDetailView: View {
    let list: TaskList

    @StateObject private var taskService = TaskService.shared
    @State private var selectedTask: Task?
    @State private var showAddTask = false
    @State private var showEditList = false

    private var tasks: [Task] {
        taskService.fetchTasks(forListID: list.id).filter { !$0.isCompleted }
    }

    private var completedTasks: [Task] {
        taskService.fetchTasks(forListID: list.id).filter { $0.isCompleted }
    }

    var body: some View {
        ZStack {
            Color.adaptiveBackground
                .ignoresSafeArea()

            if tasks.isEmpty && completedTasks.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
        .navigationTitle(list.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if !list.isDefault {
                        Button {
                            showEditList = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(Color.Lazyflow.accent)
                        }
                    }

                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.Lazyflow.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(defaultListID: list.id)
        }
        .sheet(item: $selectedTask) { task in
            if task.isSubtask {
                SubtaskDetailView(subtask: task)
            } else {
                TaskDetailView(task: task)
            }
        }
        .sheet(isPresented: $showEditList) {
            EditListSheet(list: list)
        }
        .refreshable {
            taskService.fetchAllTasks()
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        EmptyStateView(
            icon: list.icon,
            title: "No Tasks",
            message: "Add a task to this list to get started.",
            actionTitle: "Add Task"
        ) {
            showAddTask = true
        }
    }

    private var taskListView: some View {
        List {
            // Active tasks
            if !tasks.isEmpty {
                Section {
                    ForEach(tasks) { task in
                        TaskRowView(
                            task: task,
                            onToggle: { taskService.toggleTaskCompletion(task) },
                            onTap: { selectedTask = task },
                            onPushToTomorrow: { pushToTomorrow($0) },
                            onMoveToToday: { moveToToday($0) },
                            onPriorityChange: { updateTaskPriority($0, priority: $1) },
                            onDueDateChange: { updateTaskDueDate($0, dueDate: $1) },
                            onDelete: { taskService.deleteTask($0) },
                            onStartWorking: { taskService.startWorking(on: $0) },
                            onStopWorking: { taskService.stopWorking(on: $0) }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.adaptiveBackground)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    HStack {
                        ListColorDot(colorHex: list.colorHex)

                        Text("\(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Lazyflow.textSecondary)

                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            }

            // Completed tasks
            if !completedTasks.isEmpty {
                Section {
                    DisclosureGroup {
                        ForEach(completedTasks) { task in
                            TaskRowView(
                                task: task,
                                onToggle: { taskService.toggleTaskCompletion(task) },
                                onTap: { selectedTask = task },
                                onPushToTomorrow: { pushToTomorrow($0) },
                                onMoveToToday: { moveToToday($0) },
                                onPriorityChange: { updateTaskPriority($0, priority: $1) },
                                onDueDateChange: { updateTaskDueDate($0, dueDate: $1) },
                                onDelete: { taskService.deleteTask($0) },
                                onStartWorking: nil,
                                onStopWorking: nil
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.adaptiveBackground)
                            .listRowSeparator(.hidden)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.Lazyflow.success)

                            Text("Completed")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(Color.Lazyflow.textSecondary)

                            Text("\(completedTasks.count)")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(Color.Lazyflow.textTertiary)
                        }
                    }
                    .tint(Color.Lazyflow.textSecondary)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.adaptiveBackground)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveBackground)
    }

    // MARK: - Actions

    private func updateTaskPriority(_ task: Task, priority: Priority) {
        var updatedTask = task
        updatedTask.priority = priority
        taskService.updateTask(updatedTask)
    }

    private func updateTaskDueDate(_ task: Task, dueDate: Date?) {
        var updatedTask = task
        updatedTask.dueDate = dueDate
        taskService.updateTask(updatedTask)
    }

    private func pushToTomorrow(_ task: Task) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        updateTaskDueDate(task, dueDate: tomorrow)
    }

    private func moveToToday(_ task: Task) {
        updateTaskDueDate(task, dueDate: Date())
    }
}

// MARK: - Edit List Sheet

struct EditListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var listService = TaskListService.shared

    let list: TaskList

    @State private var name: String
    @State private var colorHex: String
    @State private var iconName: String
    @State private var showDeleteConfirmation = false

    init(list: TaskList) {
        self.list = list
        _name = State(initialValue: list.name)
        _colorHex = State(initialValue: list.colorHex)
        _iconName = State(initialValue: list.iconName ?? "list.bullet")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List Name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(TaskList.availableColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .gray)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: colorHex == hex ? 2 : 0)
                                        .padding(2)
                                )
                                .onTapGesture {
                                    colorHex = hex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(TaskList.availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundColor(
                                    iconName == icon
                                        ? Color(hex: colorHex)
                                        : Color.Lazyflow.textSecondary
                                )
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(
                                            iconName == icon
                                                ? Color(hex: colorHex)?.opacity(0.2) ?? Color.clear
                                                : Color.clear
                                        )
                                )
                                .onTapGesture {
                                    iconName = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete List")
                            Spacer()
                        }
                    }
                } footer: {
                    Text("Tasks will be moved to Inbox when you delete this list.")
                }
            }
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete List?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    listService.deleteList(list)
                    dismiss()
                }
            } message: {
                Text("Tasks in this list will be moved to Inbox.")
            }
        }
    }

    private func saveChanges() {
        var updatedList = list
        updatedList = TaskList(
            id: list.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: colorHex,
            iconName: iconName,
            order: list.order,
            isDefault: list.isDefault,
            createdAt: list.createdAt
        )
        listService.updateList(updatedList)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ListDetailView(list: TaskList.sampleLists[1])
    }
    .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
