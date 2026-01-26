import Foundation
import Combine
import SwiftUI

/// ViewModel for the Categories view
@MainActor
final class CategoriesViewModel: ObservableObject {
    @Published private(set) var taskCountBySystemCategory: [TaskCategory: Int] = [:]
    @Published private(set) var taskCountByCustomCategory: [UUID: Int] = [:]

    private let taskService: TaskService
    private let categoryService: CategoryService
    private var cancellables = Set<AnyCancellable>()

    init(taskService: TaskService = .shared, categoryService: CategoryService = .shared) {
        self.taskService = taskService
        self.categoryService = categoryService
        setupObservers()
        refreshCounts()
    }

    private func setupObservers() {
        // Listen for task changes
        taskService.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshCounts()
            }
            .store(in: &cancellables)

        // Listen for category changes
        categoryService.$categories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshCounts()
            }
            .store(in: &cancellables)
    }

    func refreshCounts() {
        let allTasks = taskService.tasks.filter { !$0.isCompleted && !$0.isSubtask }

        // Count tasks by system category (excluding those with custom categories)
        var systemCounts: [TaskCategory: Int] = [:]
        for category in TaskCategory.allCases {
            systemCounts[category] = 0
        }

        // Count tasks by custom category
        var customCounts: [UUID: Int] = [:]
        for category in categoryService.categories {
            customCounts[category.id] = 0
        }

        for task in allTasks {
            if let customID = task.customCategoryID {
                // Task has custom category
                customCounts[customID, default: 0] += 1
            } else {
                // Task uses system category
                systemCounts[task.category, default: 0] += 1
            }
        }

        taskCountBySystemCategory = systemCounts
        taskCountByCustomCategory = customCounts
    }

    // MARK: - Computed Properties

    var systemCategories: [TaskCategory] {
        TaskCategory.allCases
    }

    var customCategories: [CustomCategory] {
        categoryService.categories
    }

    func taskCount(for category: TaskCategory) -> Int {
        taskCountBySystemCategory[category] ?? 0
    }

    func taskCount(for categoryID: UUID) -> Int {
        taskCountByCustomCategory[categoryID] ?? 0
    }

    var totalTaskCount: Int {
        let systemTotal = taskCountBySystemCategory.values.reduce(0, +)
        let customTotal = taskCountByCustomCategory.values.reduce(0, +)
        return systemTotal + customTotal
    }
}
