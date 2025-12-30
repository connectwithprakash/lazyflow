import SwiftUI

/// View showing upcoming tasks grouped by date
struct UpcomingView: View {
    @StateObject private var taskService = TaskService()
    @State private var selectedTask: Task?
    @State private var showAddTask = false

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
        NavigationStack {
            ZStack {
                Color.adaptiveBackground
                    .ignoresSafeArea()

                if groupedTasks.isEmpty && tasksWithoutDate.isEmpty {
                    emptyStateView
                } else {
                    taskListView
                }
            }
            .navigationTitle("Upcoming")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.Taskweave.accent)
                    }
                    .accessibilityLabel("Add task")
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView()
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
            .refreshable {
                taskService.fetchAllTasks()
            }
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
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md, pinnedViews: [.sectionHeaders]) {
                // Date sections
                ForEach(groupedTasks, id: \.0) { date, tasks in
                    dateSection(date: date, tasks: tasks)
                }

                // Someday section (no due date)
                if !tasksWithoutDate.isEmpty {
                    somedaySection
                }

                Spacer(minLength: 100)
            }
        }
    }

    private func dateSection(date: Date, tasks: [Task]) -> some View {
        Section {
            ForEach(tasks) { task in
                TaskRowView(
                    task: task,
                    onToggle: { taskService.toggleTaskCompletion(task) },
                    onTap: { selectedTask = task }
                )
                .padding(.horizontal)
            }
        } header: {
            dateSectionHeader(date: date, taskCount: tasks.count)
        }
    }

    private func dateSectionHeader(date: Date, taskCount: Int) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date.shortWeekdayName.uppercased())
                    .font(DesignSystem.Typography.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.Taskweave.accent)

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(Color.Taskweave.textPrimary)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(date.relativeFormatted)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Taskweave.textPrimary)

                Text("\(taskCount) task\(taskCount == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Taskweave.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.adaptiveBackground)
    }

    private var somedaySection: some View {
        Section {
            ForEach(tasksWithoutDate) { task in
                TaskRowView(
                    task: task,
                    onToggle: { taskService.toggleTaskCompletion(task) },
                    onTap: { selectedTask = task }
                )
                .padding(.horizontal)
            }
        } header: {
            HStack {
                Image(systemName: "tray")
                    .foregroundColor(Color.Taskweave.textTertiary)

                Text("Someday")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Taskweave.textSecondary)

                Text("\(tasksWithoutDate.count)")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.textTertiary)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(Color.adaptiveBackground)
        }
    }
}

// MARK: - Preview

#Preview {
    UpcomingView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
