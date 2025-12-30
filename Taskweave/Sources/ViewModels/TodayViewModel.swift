import Foundation
import Combine

/// ViewModel for the Today view
@MainActor
final class TodayViewModel: ObservableObject {
    @Published var overdueTasks: [Task] = []
    @Published var todayTasks: [Task] = []
    @Published var completedTodayTasks: [Task] = []
    @Published var isLoading: Bool = false
    @Published var showAddTask: Bool = false
    @Published var selectedTask: Task?
    @Published var searchQuery: String = ""

    private let taskService: TaskService
    private var cancellables = Set<AnyCancellable>()

    init(taskService: TaskService = TaskService()) {
        self.taskService = taskService
        setupBindings()
    }

    private func setupBindings() {
        taskService.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTasks()
            }
            .store(in: &cancellables)

        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.filterTasks(query: query)
            }
            .store(in: &cancellables)
    }

    func refreshTasks() {
        isLoading = true
        defer { isLoading = false }

        let overdue = taskService.fetchOverdueTasks()
        let today = taskService.fetchTodayTasks()

        overdueTasks = overdue.filter { !$0.isCompleted }
        todayTasks = today.filter { !$0.isCompleted }
        completedTodayTasks = today.filter { $0.isCompleted }
    }

    private func filterTasks(query: String) {
        if query.isEmpty {
            refreshTasks()
        } else {
            let searchResults = taskService.searchTasks(query: query)
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

            todayTasks = searchResults.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= today && dueDate < tomorrow && !task.isCompleted
            }
            overdueTasks = searchResults.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < today && !task.isCompleted
            }
        }
    }

    // MARK: - Actions

    func toggleTaskCompletion(_ task: Task) {
        taskService.toggleTaskCompletion(task)
    }

    func deleteTask(_ task: Task) {
        taskService.deleteTask(task)
    }

    func createTask(title: String, priority: Priority = .none) {
        taskService.createTask(
            title: title,
            dueDate: Date(),
            priority: priority
        )
    }

    var totalTaskCount: Int {
        overdueTasks.count + todayTasks.count
    }

    var completedTaskCount: Int {
        completedTodayTasks.count
    }

    var progressPercentage: Double {
        let total = totalTaskCount + completedTaskCount
        guard total > 0 else { return 0 }
        return Double(completedTaskCount) / Double(total)
    }
}
