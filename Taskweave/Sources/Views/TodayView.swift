import SwiftUI

/// Main Today view showing overdue and today's tasks
struct TodayView: View {
    @StateObject private var viewModel = TodayViewModel()
    @State private var showAddTask = false
    @State private var taskToSchedule: Task?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveBackground
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.totalTaskCount == 0 && viewModel.completedTaskCount == 0 {
                    emptyStateView
                } else {
                    taskListView
                }
            }
            .navigationTitle("Today")
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
                AddTaskView(defaultDueDate: Date())
            }
            .sheet(item: $viewModel.selectedTask) { task in
                TaskDetailView(task: task)
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
            .refreshable {
                viewModel.refreshTasks()
            }
        }
    }

    // MARK: - Scheduling

    private func scheduleTaskAction(_ task: Task) {
        taskToSchedule = task
    }

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
        do {
            _ = try CalendarService.shared.createTimeBlock(for: task, startDate: startTime, duration: duration)
        } catch {
            print("Failed to create time block: \(error)")
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "checkmark.circle",
            title: "All Clear!",
            message: "You have no tasks due today.\nEnjoy your day or add a new task.",
            actionTitle: "Add Task"
        ) {
            showAddTask = true
        }
    }

    private var taskListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md, pinnedViews: [.sectionHeaders]) {
                // Progress header
                progressHeader
                    .padding(.horizontal)
                    .padding(.top, DesignSystem.Spacing.sm)

                // Overdue section
                if !viewModel.overdueTasks.isEmpty {
                    taskSection(
                        title: "Overdue",
                        tasks: viewModel.overdueTasks,
                        accentColor: Color.Taskweave.error
                    )
                }

                // Today section
                if !viewModel.todayTasks.isEmpty {
                    taskSection(
                        title: "Today",
                        tasks: viewModel.todayTasks,
                        accentColor: Color.Taskweave.accent
                    )
                }

                // Completed section
                if !viewModel.completedTodayTasks.isEmpty {
                    completedSection
                }

                Spacer(minLength: 100)
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(Date().fullFormatted)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.textSecondary)

                Spacer()

                Text("\(viewModel.completedTaskCount)/\(viewModel.totalTaskCount + viewModel.completedTaskCount) done")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.Taskweave.accent)
                        .frame(width: geometry.size.width * viewModel.progressPercentage, height: 8)
                        .animation(.spring(), value: viewModel.progressPercentage)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private func taskSection(title: String, tasks: [Task], accentColor: Color) -> some View {
        Section {
            ForEach(tasks) { task in
                TaskRowView(
                    task: task,
                    onToggle: { viewModel.toggleTaskCompletion(task) },
                    onTap: { viewModel.selectedTask = task },
                    onSchedule: { scheduleTaskAction($0) }
                )
                .padding(.horizontal)
            }
        } header: {
            HStack {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Taskweave.textPrimary)

                Text("\(tasks.count)")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.textSecondary)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(Color.adaptiveBackground)
        }
    }

    private var completedSection: some View {
        DisclosureGroup {
            ForEach(viewModel.completedTodayTasks) { task in
                TaskRowView(
                    task: task,
                    onToggle: { viewModel.toggleTaskCompletion(task) },
                    onTap: { viewModel.selectedTask = task },
                    onSchedule: nil // Completed tasks don't need scheduling
                )
                .padding(.horizontal)
            }
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.Taskweave.success)

                Text("Completed")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Taskweave.textSecondary)

                Text("\(viewModel.completedTodayTasks.count)")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.textTertiary)
            }
        }
        .padding(.horizontal)
        .tint(Color.Taskweave.textSecondary)
    }
}

// MARK: - Preview

#Preview {
    TodayView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
