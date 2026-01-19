import SwiftUI

/// View showing completed tasks history with date filtering and search
struct HistoryView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedTask: Task?
    @State private var showFilters = false

    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: No NavigationStack (provided by split view)
            historyContent
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .sheet(item: $selectedTask) { task in
                    TaskDetailView(task: task)
                }
                .sheet(isPresented: $showFilters) {
                    HistoryFiltersSheet(viewModel: viewModel)
                }
        } else {
            // iPhone: Full NavigationStack
            NavigationStack {
                historyContent
                    .navigationTitle("History")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbarContent }
                    .sheet(item: $selectedTask) { task in
                        TaskDetailView(task: task)
                    }
                    .sheet(isPresented: $showFilters) {
                        HistoryFiltersSheet(viewModel: viewModel)
                    }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showFilters = true
            } label: {
                Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundColor(Color.Lazyflow.accent)
            }
            .accessibilityLabel("Filters")
        }
    }

    // MARK: - Content

    private var historyContent: some View {
        VStack(spacing: 0) {
            // Date range picker
            dateRangeHeader

            // Search bar
            searchBar

            if viewModel.completedTasks.isEmpty {
                emptyStateView
                    .frame(maxHeight: .infinity)
            } else {
                taskListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.adaptiveBackground)
        .refreshable {
            viewModel.refreshTasks()
        }
    }

    // MARK: - Date Range Header

    private var dateRangeHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Date pickers - centered
            HStack(spacing: DesignSystem.Spacing.sm) {
                DatePicker(
                    "From",
                    selection: $viewModel.startDate,
                    in: ...viewModel.endDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(Color.Lazyflow.textTertiary)

                DatePicker(
                    "To",
                    selection: $viewModel.endDate,
                    in: viewModel.startDate...,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Preset buttons - evenly distributed with equal widths
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(DateRangePreset.allCases.filter { $0 != .custom }) { preset in
                    presetButton(preset)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.sm)
    }

    private func presetButton(_ preset: DateRangePreset) -> some View {
        let isSelected = viewModel.selectedPreset == preset
        return Button {
            viewModel.setPresetDateRange(preset)
        } label: {
            Text(preset.rawValue)
                .font(DesignSystem.Typography.caption1)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .white : Color.Lazyflow.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    isSelected
                        ? Color.Lazyflow.accent
                        : Color.Lazyflow.accent.opacity(0.15)
                )
                .cornerRadius(DesignSystem.CornerRadius.medium)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.Lazyflow.textTertiary)

            TextField("Search", text: $viewModel.searchQuery)
                .font(DesignSystem.Typography.body)
                .textFieldStyle(.plain)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.Lazyflow.textTertiary)
                }
            }

            // Count badge
            Text("\(viewModel.totalCompletedCount) found")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(Color.Lazyflow.accent.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    // MARK: - Task List

    private var taskListView: some View {
        List {
            ForEach(viewModel.groupedTasks) { group in
                Section {
                    ForEach(group.tasks) { task in
                        HistoryTaskRow(
                            task: task,
                            onTap: { selectedTask = task },
                            onUncomplete: { viewModel.uncompleteTask(task) }
                        )
                        .listRowInsets(EdgeInsets(
                            top: DesignSystem.Spacing.xs,
                            leading: DesignSystem.Spacing.lg,
                            bottom: DesignSystem.Spacing.xs,
                            trailing: DesignSystem.Spacing.lg
                        ))
                        .listRowBackground(Color.adaptiveBackground)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    dateSectionHeader(date: group.date, taskCount: group.tasks.count)
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

                Text("\(taskCount) task\(taskCount == 1 ? "" : "s") completed")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "checkmark.circle",
            title: "No Completed Tasks",
            message: viewModel.hasActiveFilters
                ? "No tasks match your filters.\nTry adjusting your search or filters."
                : "Complete some tasks to see them here.\nYour history will show all completed tasks."
        )
    }
}

// MARK: - History Task Row

struct HistoryTaskRow: View {
    let task: Task
    let onTap: () -> Void
    let onUncomplete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Completed checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color.Lazyflow.success)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(task.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(Color.Lazyflow.textPrimary)
                        .strikethrough(true, color: Color.Lazyflow.textTertiary)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if let completedAt = task.completedAt {
                            Text(completedAt.formatted(date: .omitted, time: .shortened))
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textTertiary)
                        }

                        if task.priority != .none {
                            PriorityBadge(priority: task.priority)
                        }

                        if let duration = task.formattedActualDuration {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(duration)
                                    .font(DesignSystem.Typography.caption2)
                            }
                            .foregroundColor(Color.Lazyflow.textTertiary)
                        }
                    }
                }

                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color.adaptiveSurface)
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onUncomplete()
            } label: {
                Label("Mark Incomplete", systemImage: "arrow.uturn.backward")
            }

            Button(role: .destructive) {
                // Delete functionality would go here
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel("\(task.title), completed")
        .accessibilityHint("Double tap to view details")
    }
}

// MARK: - Filters Sheet

struct HistoryFiltersSheet: View {
    @ObservedObject var viewModel: HistoryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Priority Filter
                Section("Priority") {
                    Picker("Priority", selection: $viewModel.selectedPriority) {
                        Text("All").tag(nil as Priority?)
                        ForEach(Priority.allCases, id: \.self) { priority in
                            Label(priority.displayName, systemImage: priority.iconName)
                                .tag(priority as Priority?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // List Filter
                Section("List") {
                    Picker("List", selection: $viewModel.selectedListID) {
                        Text("All Lists").tag(nil as UUID?)
                        ForEach(viewModel.availableLists) { list in
                            Label(list.name, systemImage: list.icon)
                                .tag(list.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Clear Filters
                if viewModel.hasActiveFilters {
                    Section {
                        Button("Clear All Filters") {
                            viewModel.clearFilters()
                        }
                        .foregroundColor(Color.Lazyflow.error)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
