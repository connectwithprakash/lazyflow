import SwiftUI

/// View showing completed tasks history with stats and filtering
struct HistoryView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedTask: Task?
    @State private var showFilters = false
    @FocusState private var isSearchFocused: Bool

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
                    .foregroundColor(Color.Lazyflow.accent)
            }
            .accessibilityLabel("Filters")
        }
    }

    // MARK: - Content

    private var historyContent: some View {
        VStack(spacing: 0) {
            Group {
                if viewModel.completedTasks.isEmpty {
                    VStack(spacing: 0) {
                        statsHeader
                        emptyStateView
                            .frame(maxHeight: .infinity)
                    }
                } else {
                    taskListView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .safeAreaInset(edge: .bottom) {
            bottomSearchBar
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isSearchFocused = false
                }
            }
        }
        .background(Color.adaptiveBackground)
    }

    private var bottomSearchBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.Lazyflow.textSecondary)

                TextField("Search completed tasks...", text: $viewModel.searchQuery)
                    .font(DesignSystem.Typography.body)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .accessibilityLabel("Search history")

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.Lazyflow.textTertiary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(Color.Lazyflow.textPrimary.opacity(0.08))
            )

            if isSearchFocused {
                Button("Cancel") {
                    isSearchFocused = false
                    viewModel.searchQuery = ""
                }
                .font(DesignSystem.Typography.body)
                .foregroundColor(Color.Lazyflow.accent)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            Color.adaptiveBackground
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -2)
        )
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Main stat
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                    Text("\(viewModel.periodStats.completedCount)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Color.Lazyflow.textPrimary)

                    Text(viewModel.periodStats.completedCount == 1 ? "task" : "tasks")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                // Trend indicator below (always reserve space to prevent layout shift)
                trendBadge
                    .opacity(viewModel.periodStats.previousCount > 0 || viewModel.periodStats.completedCount > 0 ? 1 : 0)
            }

            // Date range tabs - direct tap
            dateRangeTabs
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    private var trendBadge: some View {
        let stats = viewModel.periodStats
        let trendColor: Color = {
            switch stats.trend {
            case .up: return Color.Lazyflow.success
            case .down: return Color.Lazyflow.error
            case .neutral: return Color.Lazyflow.textSecondary
            }
        }()

        return HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: stats.trend.icon)
                .font(.caption)

            Text("\(abs(stats.percentChange))%")
                .font(DesignSystem.Typography.caption1)
                .fontWeight(.medium)

            Text("vs last \(periodName)")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textTertiary)
        }
        .foregroundColor(trendColor)
    }

    private var periodName: String {
        switch viewModel.selectedPreset {
        case .recent: return "week"
        case .thisMonth: return "month"
        case .lastMonth: return "month"
        case .custom: return "period"
        }
    }

    private var dateRangeTabs: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(DateRangePreset.allCases.filter { $0 != .custom }) { preset in
                dateRangeTab(preset)
            }
        }
    }

    private func dateRangeTab(_ preset: DateRangePreset) -> some View {
        let isSelected = viewModel.selectedPreset == preset

        return Button {
            viewModel.setPresetDateRange(preset)
        } label: {
            Text(preset.rawValue)
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .white : Color.Lazyflow.accent)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    isSelected
                        ? Color.Lazyflow.accent
                        : Color.Lazyflow.accent.opacity(0.1)
                )
                .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - Task List

    private var taskListView: some View {
        List {
            // Stats header as first section
            Section {
                statsHeader
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            .listRowSeparator(.hidden)

            // Task groups
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
            Text(formatSectionDate(date))
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textPrimary)

            Text("·")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textTertiary)

            Text("\(taskCount)")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
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
                    .font(.title3)
                    .foregroundColor(Color.Lazyflow.success)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(task.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(Color.Lazyflow.textPrimary)

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
                // Date Range Section
                Section("Date Range") {
                    DatePicker(
                        "From",
                        selection: $viewModel.startDate,
                        in: ...viewModel.endDate,
                        displayedComponents: .date
                    )

                    DatePicker(
                        "To",
                        selection: $viewModel.endDate,
                        in: viewModel.startDate...,
                        displayedComponents: .date
                    )
                }

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
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
