import Foundation
import Combine

/// ViewModel for Watch task management
@MainActor
final class WatchViewModel: ObservableObject {
    @Published private(set) var tasks: [WatchTask] = []
    @Published private(set) var isLoading = false

    private let connectivityService = WatchConnectivityService.shared
    private let dataStore = WatchDataStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load cached tasks immediately
        tasks = dataStore.todayTasks

        // Subscribe to connectivity service updates
        connectivityService.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.tasks = tasks
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties

    var incompleteTasks: [WatchTask] {
        tasks.filter { !$0.isCompleted }
            .sorted { $0.priority > $1.priority }
    }

    var completedTasks: [WatchTask] {
        tasks.filter { $0.isCompleted }
    }

    var completedCount: Int {
        completedTasks.count
    }

    var totalCount: Int {
        tasks.count
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var allComplete: Bool {
        totalCount > 0 && completedCount == totalCount
    }

    var isEmpty: Bool {
        tasks.isEmpty
    }

    // MARK: - Actions

    func refresh() {
        isLoading = true
        connectivityService.requestSync()

        // Reset loading after a timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isLoading = false
        }
    }

    func toggleCompletion(_ task: WatchTask) {
        guard !task.isCompleted else { return }
        connectivityService.toggleTaskCompletion(task)
    }
}
