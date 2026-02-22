import SwiftUI

/// View showing upcoming tasks grouped by date
struct UpcomingView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var focusCoordinator: FocusSessionCoordinator
    @StateObject private var taskService = TaskService.shared
    @StateObject private var listService = TaskListService.shared
    @State private var selectedTask: Task?
    @State private var showAddTask = false
    @State private var taskToSchedule: Task?

    private var groupedTasks: [(Date, [Task])] {
        let upcoming = taskService.fetchUpcomingTasks()
        let grouped = Dictionary(grouping: upcoming) { task -> Date in
            guard let dueDate = task.dueDate else { return Date() }
            return Calendar.current.startOfDay(for: dueDate)
        }

        return grouped.sorted { $0.key < $1.key }
    }

    private var tasksWithoutDate: [Task] {
        taskService.fetchTasksWithoutDueDate()
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: No NavigationStack (provided by split view)
            upcomingContent
                .navigationTitle("Upcoming")
                .toolbar { addTaskToolbar }
                .sheet(isPresented: $showAddTask) { AddTaskView() }
                .sheet(item: $selectedTask) { task in
                    if task.isSubtask {
                        SubtaskDetailView(subtask: task)
                    } else {
                        TaskDetailView(task: task)
                    }
                }
                .sheet(item: $taskToSchedule) { task in
                    TimeBlockSheet(
                        task: task,
                        startTime: defaultScheduleTime(),
                        onConfirm: { startTime, duration in
                            scheduleTask(task, startTime: startTime, duration: duration)
                        }
                    )
                }
        } else {
            // iPhone: Full NavigationStack
            NavigationStack {
                upcomingContent
                    .navigationTitle("Upcoming")
                    .toolbar { addTaskToolbar }
                    .sheet(isPresented: $showAddTask) { AddTaskView() }
                    .sheet(item: $selectedTask) { task in
                        if task.isSubtask {
                            SubtaskDetailView(subtask: task)
                        } else {
                            TaskDetailView(task: task)
                        }
                    }
                    .sheet(item: $taskToSchedule) { task in
                        TimeBlockSheet(
                            task: task,
                            startTime: defaultScheduleTime(),
                            onConfirm: { startTime, duration in
                                scheduleTask(task, startTime: startTime, duration: duration)
                            }
                        )
                    }
            }
        }
    }

    @ToolbarContentBuilder
    private var addTaskToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showAddTask = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color.Lazyflow.accent)
            }
            .accessibilityLabel("Add task")
        }
    }

    private var upcomingContent: some View {
        ZStack {
            Color.adaptiveBackground
                .ignoresSafeArea()

            if groupedTasks.isEmpty && tasksWithoutDate.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
        .refreshable {
            taskService.fetchAllTasks()
        }
        .onAppear {
            // Explicitly fetch tasks when view appears to ensure fresh data
            taskService.fetchAllTasks()
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "calendar",
            title: "No Upcoming Tasks",
            message: "Tasks with due dates will appear here.\nAdd a task with a future date to get started.",
            actionTitle: "Add Task"
        ) {
            showAddTask = true
        }
    }

    private var taskListView: some View {
        List {
            // Date sections
            ForEach(groupedTasks, id: \.0) { date, tasks in
                Section {
                    ForEach(tasks) { task in
                        TaskRowView(
                            task: task,
                            onToggle: { taskService.toggleTaskCompletion(task) },
                            onTap: { selectedTask = task },
                            onSchedule: { taskToSchedule = $0 },
                            onPushToTomorrow: { pushToTomorrow($0) },
                            onMoveToToday: { moveToToday($0) },
                            onPriorityChange: { updateTaskPriority($0, priority: $1) },
                            onDueDateChange: { updateTaskDueDate($0, dueDate: $1) },
                            onDelete: { taskService.deleteTask($0) },
                            onStartWorking: { $0.accumulatedDuration > 0 ? taskService.resumeWorking(on: $0) : taskService.startWorking(on: $0) },
                            onStopWorking: { taskService.stopWorking(on: $0) },
                            onEnterFocus: { focusCoordinator.enterFocus(task: $0) },
                            showListIndicator: true,
                            listColorHex: listColorHex(for: task)
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.adaptiveBackground)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    dateSectionHeader(date: date, taskCount: tasks.count)
                }
            }

            // Someday section (no due date)
            if !tasksWithoutDate.isEmpty {
                Section {
                    ForEach(tasksWithoutDate) { task in
                        TaskRowView(
                            task: task,
                            onToggle: { taskService.toggleTaskCompletion(task) },
                            onTap: { selectedTask = task },
                            onSchedule: { taskToSchedule = $0 },
                            onPushToTomorrow: { pushToTomorrow($0) },
                            onMoveToToday: { moveToToday($0) },
                            onPriorityChange: { updateTaskPriority($0, priority: $1) },
                            onDueDateChange: { updateTaskDueDate($0, dueDate: $1) },
                            onDelete: { taskService.deleteTask($0) },
                            onStartWorking: { $0.accumulatedDuration > 0 ? taskService.resumeWorking(on: $0) : taskService.startWorking(on: $0) },
                            onStopWorking: { taskService.stopWorking(on: $0) },
                            onEnterFocus: { focusCoordinator.enterFocus(task: $0) },
                            showListIndicator: true,
                            listColorHex: listColorHex(for: task)
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.adaptiveBackground)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    somedaySectionHeader
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveBackground)
    }

    private func dateSectionHeader(date: Date, taskCount: Int) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date.shortWeekdayName.uppercased())
                    .font(DesignSystem.Typography.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.Lazyflow.accent)

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(Color.Lazyflow.textPrimary)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(date.relativeFormatted)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Text("\(taskCount) task\(taskCount == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private var somedaySectionHeader: some View {
        HStack {
            Image(systemName: "tray")
                .foregroundColor(Color.Lazyflow.textTertiary)

            Text("Someday")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textSecondary)

            Text("\(tasksWithoutDate.count)")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textTertiary)

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
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

    private func listColorHex(for task: Task) -> String? {
        guard let listID = task.listID,
              let list = listService.getList(byID: listID),
              !list.isDefault else { return nil }
        return list.colorHex
    }

    private func pushToTomorrow(_ task: Task) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        updateTaskDueDate(task, dueDate: tomorrow)
    }

    private func moveToToday(_ task: Task) {
        updateTaskDueDate(task, dueDate: Date())
    }

    // MARK: - Scheduling

    private func defaultScheduleTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        // Default to next hour
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        if let nextHour = calendar.date(from: components)?.addingTimeInterval(3600) {
            return nextHour
        }
        return now
    }

    private func scheduleTask(_ task: Task, startTime: Date, duration: TimeInterval) {
        try? TaskService.shared.createCalendarEvent(for: task, startDate: startTime, duration: duration)
    }
}

// MARK: - Preview

#Preview {
    UpcomingView()
        .environmentObject(FocusSessionCoordinator())
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
