import Foundation
import Combine

/// ViewModel for the Lists view
@MainActor
final class ListsViewModel: ObservableObject {
    @Published var lists: [TaskList] = []
    @Published var taskCounts: [UUID: Int] = [:]
    @Published var isLoading: Bool = false
    @Published var showAddList: Bool = false
    @Published var selectedList: TaskList?
    @Published var editingList: TaskList?

    // New list form
    @Published var newListName: String = ""
    @Published var newListColor: String = TaskList.availableColors[0]
    @Published var newListIcon: String = "list.bullet"

    private let taskListService: TaskListService
    private let taskService: TaskService
    private var cancellables = Set<AnyCancellable>()

    init(taskListService: TaskListService = TaskListService(), taskService: TaskService = TaskService()) {
        self.taskListService = taskListService
        self.taskService = taskService
        setupBindings()
    }

    private func setupBindings() {
        taskListService.$lists
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lists in
                self?.lists = lists
                self?.updateTaskCounts()
            }
            .store(in: &cancellables)

        taskService.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTaskCounts()
            }
            .store(in: &cancellables)
    }

    private func updateTaskCounts() {
        var counts: [UUID: Int] = [:]
        for list in lists {
            counts[list.id] = taskListService.getTaskCount(forListID: list.id)
        }
        taskCounts = counts
    }

    // MARK: - Actions

    func createList() {
        guard !newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        taskListService.createList(
            name: newListName.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: newListColor,
            iconName: newListIcon
        )

        // Reset form
        newListName = ""
        newListColor = TaskList.availableColors[0]
        newListIcon = "list.bullet"
        showAddList = false
    }

    func updateList(_ list: TaskList) {
        taskListService.updateList(list)
    }

    func deleteList(_ list: TaskList) {
        taskListService.deleteList(list)
    }

    func moveList(from source: IndexSet, to destination: Int) {
        var reorderedLists = lists
        reorderedLists.move(fromOffsets: source, toOffset: destination)
        taskListService.reorderLists(reorderedLists)
    }

    func getTaskCount(for list: TaskList) -> Int {
        taskCounts[list.id] ?? 0
    }

    func getTasks(for list: TaskList) -> [Task] {
        taskService.fetchTasks(forListID: list.id)
    }

    var canCreateList: Bool {
        !newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Smart Lists

    var inboxList: TaskList? {
        taskListService.getInboxList()
    }

    var inboxTaskCount: Int {
        guard let inbox = inboxList else { return 0 }
        return getTaskCount(for: inbox)
    }

    var todayTaskCount: Int {
        taskService.fetchTodayTasks().filter { !$0.isCompleted }.count
    }

    var upcomingTaskCount: Int {
        taskService.fetchUpcomingTasks().filter { !$0.isCompleted }.count
    }

    var customLists: [TaskList] {
        lists.filter { !$0.isDefault }
    }
}
