import Foundation
import Combine

/// Preset date ranges for quick filtering
enum DateRangePreset: String, CaseIterable, Identifiable {
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case custom = "Custom"

    var id: String { rawValue }
}

/// Group of tasks completed on a specific date
struct TaskDateGroup: Identifiable, Equatable {
    let date: Date
    let tasks: [Task]

    var id: Date { date }

    static func == (lhs: TaskDateGroup, rhs: TaskDateGroup) -> Bool {
        lhs.date == rhs.date && lhs.tasks == rhs.tasks
    }
}

/// ViewModel for the History view - displays completed tasks with filtering
@MainActor
final class HistoryViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var completedTasks: [Task] = []
    @Published private(set) var groupedTasks: [TaskDateGroup] = []
    @Published private(set) var isLoading: Bool = false

    // Filters
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var selectedListID: UUID?
    @Published var selectedPriority: Priority?
    @Published var searchQuery: String = ""
    @Published var selectedPreset: DateRangePreset = .last7Days

    // Flag to prevent date observers from resetting preset during programmatic changes
    private var isSettingPresetDates = false

    // MARK: - Dependencies

    private let taskService: TaskService
    private let taskListService: TaskListService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var totalCompletedCount: Int {
        completedTasks.count
    }

    var hasActiveFilters: Bool {
        selectedListID != nil || selectedPriority != nil || !searchQuery.isEmpty
    }

    var availableLists: [TaskList] {
        taskListService.lists
    }

    // MARK: - Initialization

    init(taskService: TaskService = .shared, taskListService: TaskListService = .init()) {
        self.taskService = taskService
        self.taskListService = taskListService

        // Default to last 7 days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        self.endDate = today
        self.startDate = calendar.date(byAdding: .day, value: -7, to: today) ?? today

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Refresh when task service updates
        taskService.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTasks()
            }
            .store(in: &cancellables)

        // Debounced search
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTasks()
            }
            .store(in: &cancellables)

        // React to filter changes
        $selectedListID
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshTasks()
            }
            .store(in: &cancellables)

        $selectedPriority
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshTasks()
            }
            .store(in: &cancellables)

        $startDate
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self, !self.isSettingPresetDates else { return }
                self.selectedPreset = .custom
                self.refreshTasks()
            }
            .store(in: &cancellables)

        $endDate
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self, !self.isSettingPresetDates else { return }
                self.selectedPreset = .custom
                self.refreshTasks()
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Fetching

    func refreshTasks() {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let startOfStartDate = calendar.startOfDay(for: startDate)
        let endOfEndDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate

        // Fetch all completed tasks
        var tasks = taskService.tasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= startOfStartDate && completedAt < endOfEndDate
        }

        // Apply list filter
        if let listID = selectedListID {
            tasks = tasks.filter { $0.listID == listID }
        }

        // Apply priority filter
        if let priority = selectedPriority {
            tasks = tasks.filter { $0.priority == priority }
        }

        // Apply search filter
        if !searchQuery.isEmpty {
            let lowercasedQuery = searchQuery.lowercased()
            tasks = tasks.filter { task in
                task.title.lowercased().contains(lowercasedQuery) ||
                (task.notes?.lowercased().contains(lowercasedQuery) ?? false)
            }
        }

        // Sort by completion date (newest first)
        tasks.sort { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) }

        completedTasks = tasks
        groupedTasks = groupTasksByDate(tasks)
    }

    private func groupTasksByDate(_ tasks: [Task]) -> [TaskDateGroup] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: tasks) { task -> Date in
            guard let completedAt = task.completedAt else { return Date() }
            return calendar.startOfDay(for: completedAt)
        }

        return grouped
            .map { TaskDateGroup(date: $0.key, tasks: $0.value) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Filter Actions

    func setPresetDateRange(_ preset: DateRangePreset) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Prevent date observers from resetting preset
        isSettingPresetDates = true
        defer {
            isSettingPresetDates = false
            refreshTasks()
        }

        selectedPreset = preset

        switch preset {
        case .last7Days:
            startDate = calendar.date(byAdding: .day, value: -7, to: today) ?? today
            endDate = today

        case .last30Days:
            startDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
            endDate = today

        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: today)
            startDate = calendar.date(from: components) ?? today
            endDate = today

        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: today) ?? today
            let components = calendar.dateComponents([.year, .month], from: lastMonth)
            startDate = calendar.date(from: components) ?? lastMonth
            // End of last month
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
            endDate = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? lastMonth

        case .custom:
            // No change for custom
            break
        }

        refreshTasks()
    }

    func clearFilters() {
        selectedListID = nil
        selectedPriority = nil
        searchQuery = ""
    }

    // MARK: - Task Actions

    func uncompleteTask(_ task: Task) {
        taskService.toggleTaskCompletion(task)
    }

    func deleteTask(_ task: Task) {
        taskService.deleteTask(task)
    }
}
