import SwiftUI

/// Global search view for finding tasks
struct SearchView: View {
    @StateObject private var taskService = TaskService()
    @State private var searchText = ""
    @State private var selectedTask: Task?
    @FocusState private var isSearchFocused: Bool

    private var searchResults: [Task] {
        taskService.searchTasks(query: searchText)
    }

    private var recentTasks: [Task] {
        Array(taskService.tasks.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                        .padding()

                    if searchText.isEmpty {
                        recentSearchesView
                    } else if searchResults.isEmpty {
                        noResultsView
                    } else {
                        searchResultsView
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
            .onAppear {
                isSearchFocused = true
            }
        }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.Taskweave.textTertiary)

            TextField("Search tasks...", text: $searchText)
                .font(DesignSystem.Typography.body)
                .focused($isSearchFocused)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.Taskweave.textTertiary)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private var recentSearchesView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                if !recentTasks.isEmpty {
                    Text("Recent Tasks")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Taskweave.textSecondary)
                        .padding(.horizontal)

                    ForEach(recentTasks) { task in
                        RecentTaskRow(task: task) {
                            selectedTask = task
                        }
                        .padding(.horizontal)
                    }
                }

                // Search suggestions
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Try searching for")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Taskweave.textSecondary)
                        .padding(.horizontal)
                        .padding(.top)

                    ForEach(searchSuggestions, id: \.self) { suggestion in
                        Button {
                            searchText = suggestion
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color.Taskweave.textTertiary)
                                Text(suggestion)
                                    .foregroundColor(Color.Taskweave.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private var searchSuggestions: [String] {
        ["high priority", "overdue", "today", "this week"]
    }

    private var noResultsView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Color.Taskweave.textTertiary)

            Text("No Results")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(Color.Taskweave.textPrimary)

            Text("No tasks match \"\(searchText)\"")
                .font(DesignSystem.Typography.body)
                .foregroundColor(Color.Taskweave.textSecondary)

            Spacer()
        }
    }

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                ForEach(searchResults) { task in
                    SearchResultRow(
                        task: task,
                        searchQuery: searchText
                    ) {
                        selectedTask = task
                    } onToggle: {
                        taskService.toggleTaskCompletion(task)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Recent Task Row

struct RecentTaskRow: View {
    let task: Task
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(Color.Taskweave.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(Color.Taskweave.textPrimary)
                        .lineLimit(1)

                    if let date = task.dueDate {
                        Text(date.relativeFormatted)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Taskweave.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.Taskweave.textTertiary)
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let task: Task
    let searchQuery: String
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                TaskCheckbox(
                    isCompleted: task.isCompleted,
                    priority: task.priority,
                    action: onToggle
                )

                VStack(alignment: .leading, spacing: 2) {
                    highlightedTitle

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if let date = task.dueDate {
                            Text(date.relativeFormatted)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(
                                    task.isOverdue
                                        ? Color.Taskweave.error
                                        : Color.Taskweave.textSecondary
                                )
                        }

                        if task.priority != .none {
                            PriorityBadge(priority: task.priority)
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(Color.adaptiveSurface)
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var highlightedTitle: some View {
        let title = task.title
        let query = searchQuery.lowercased()

        if let range = title.lowercased().range(of: query) {
            let beforeMatch = String(title[..<range.lowerBound])
            let match = String(title[range])
            let afterMatch = String(title[range.upperBound...])

            return Text(beforeMatch)
                .foregroundColor(Color.Taskweave.textPrimary) +
            Text(match)
                .foregroundColor(Color.Taskweave.accent)
                .fontWeight(.semibold) +
            Text(afterMatch)
                .foregroundColor(Color.Taskweave.textPrimary)
        } else {
            return Text(title)
                .foregroundColor(Color.Taskweave.textPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    SearchView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
