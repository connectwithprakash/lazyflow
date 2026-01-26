import SwiftUI

/// Detail view showing tasks for a specific category
struct CategoryDetailView: View {
    let categoryName: String
    let categoryIcon: String
    let categoryColor: Color

    // For system categories
    let systemCategory: TaskCategory?
    // For custom categories
    let customCategoryID: UUID?

    @StateObject private var taskService = TaskService.shared
    @State private var selectedTask: Task?
    @State private var showAddTask = false

    init(systemCategory: TaskCategory) {
        self.categoryName = systemCategory.displayName
        self.categoryIcon = systemCategory.iconName
        self.categoryColor = systemCategory.color
        self.systemCategory = systemCategory
        self.customCategoryID = nil
    }

    init(customCategory: CustomCategory) {
        self.categoryName = customCategory.displayName
        self.categoryIcon = customCategory.iconName
        self.categoryColor = customCategory.color
        self.systemCategory = nil
        self.customCategoryID = customCategory.id
    }

    private var tasks: [Task] {
        let allTasks = taskService.tasks.filter { !$0.isCompleted && !$0.isSubtask }

        if let customID = customCategoryID {
            return allTasks.filter { $0.customCategoryID == customID }
        } else if let sysCategory = systemCategory {
            return allTasks.filter { $0.customCategoryID == nil && $0.category == sysCategory }
        }
        return []
    }

    private var completedTasks: [Task] {
        let allTasks = taskService.tasks.filter { $0.isCompleted && !$0.isSubtask }

        if let customID = customCategoryID {
            return allTasks.filter { $0.customCategoryID == customID }
        } else if let sysCategory = systemCategory {
            return allTasks.filter { $0.customCategoryID == nil && $0.category == sysCategory }
        }
        return []
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
        .navigationTitle(categoryName)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddTask = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.Lazyflow.accent)
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(
                defaultCategory: systemCategory,
                defaultCustomCategoryID: customCategoryID
            )
        }
        .sheet(item: $selectedTask) { task in
            if task.isSubtask {
                SubtaskDetailView(subtask: task)
            } else {
                TaskDetailView(task: task)
            }
        }
        .refreshable {
            taskService.fetchAllTasks()
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        EmptyStateView(
            icon: categoryIcon,
            title: "No Tasks",
            message: "Add a task to this category to get started.",
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
                        Image(systemName: categoryIcon)
                            .foregroundColor(categoryColor)
                            .font(.system(size: 14))

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

// MARK: - Preview

#Preview {
    NavigationStack {
        CategoryDetailView(systemCategory: .work)
    }
}
