import Foundation
@testable import Lazyflow

/// Factory for deterministic test data used in snapshot tests.
enum SnapshotFixtures {

    // MARK: - Fixed Dates

    /// A fixed "now" so snapshot output is deterministic regardless of when tests run.
    static let fixedNow: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 15
        components.hour = 10
        components.minute = 0
        return Calendar.current.date(from: components)!
    }()

    static let yesterday: Date = Calendar.current.date(byAdding: .day, value: -1, to: fixedNow)!
    static let twoDaysAgo: Date = Calendar.current.date(byAdding: .day, value: -2, to: fixedNow)!
    static let tomorrow: Date = Calendar.current.date(byAdding: .day, value: 1, to: fixedNow)!
    static let nextWeek: Date = Calendar.current.date(byAdding: .day, value: 7, to: fixedNow)!

    // MARK: - Sample Tasks

    static func overdueTask() -> Task {
        Task(
            title: "Submit quarterly report",
            notes: "Include Q2 revenue numbers",
            dueDate: twoDaysAgo,
            priority: .high,
            category: .work,
            estimatedDuration: 3600
        )
    }

    static func todayTaskUrgent() -> Task {
        Task(
            title: "Call dentist for appointment",
            dueDate: fixedNow,
            priority: .urgent,
            category: .health
        )
    }

    static func todayTaskMedium() -> Task {
        Task(
            title: "Buy groceries for dinner",
            dueDate: fixedNow,
            priority: .medium,
            category: .shopping
        )
    }

    static func todayTaskLow() -> Task {
        Task(
            title: "Review pull request #42",
            notes: "Check the new API endpoints",
            dueDate: fixedNow,
            priority: .low,
            category: .work,
            estimatedDuration: 1800
        )
    }

    static func upcomingTask() -> Task {
        Task(
            title: "Prepare presentation slides",
            dueDate: tomorrow,
            priority: .medium,
            category: .work
        )
    }

    static func nextWeekTask() -> Task {
        Task(
            title: "Book flight to conference",
            dueDate: nextWeek,
            priority: .low,
            category: .work
        )
    }

    static func noDateTask() -> Task {
        Task(
            title: "Learn SwiftUI animations",
            priority: .none,
            category: .learning
        )
    }

    static func completedTodayTask() -> Task {
        Task(
            title: "Morning standup meeting",
            dueDate: fixedNow,
            status: .completed,
            priority: .none,
            category: .work,
            completedAt: fixedNow
        )
    }

    static func taskWithSubtasks() -> Task {
        let parentID = UUID()
        let subtask1 = Task(
            title: "Research competitors",
            dueDate: fixedNow,
            priority: .medium,
            category: .work,
            parentTaskID: parentID
        )
        let subtask2 = Task(
            title: "Draft outline",
            dueDate: fixedNow,
            status: .completed,
            priority: .low,
            category: .work,
            completedAt: fixedNow,
            parentTaskID: parentID
        )
        return Task(
            id: parentID,
            title: "Write blog post about SwiftUI",
            dueDate: fixedNow,
            priority: .medium,
            category: .work,
            estimatedDuration: 7200,
            subtasks: [subtask1, subtask2]
        )
    }

    // MARK: - Mock Services

    /// A MockTaskService populated with a variety of tasks for the Today view.
    static func populatedTaskService() -> MockTaskService {
        let service = MockTaskService()
        service.tasks = [
            overdueTask(),
            todayTaskUrgent(),
            todayTaskMedium(),
            todayTaskLow(),
            taskWithSubtasks(),
            completedTodayTask(),
        ]
        return service
    }

    /// A MockTaskService with upcoming and no-date tasks for the Upcoming view.
    static func upcomingTaskService() -> MockTaskService {
        let service = MockTaskService()
        service.tasks = [
            upcomingTask(),
            nextWeekTask(),
            noDateTask(),
        ]
        return service
    }

    /// An empty MockTaskService.
    static func emptyTaskService() -> MockTaskService {
        return MockTaskService()
    }

    // MARK: - Quick Notes

    static func sampleNote() -> QuickNote {
        QuickNote(
            text: "Buy groceries tomorrow and call dentist next week. Also need to finish the report by Friday."
        )
    }

    // MARK: - Task Drafts

    static func sampleDrafts() -> [TaskDraft] {
        [
            TaskDraft(
                title: "Buy groceries",
                dueDate: tomorrow,
                priority: .medium,
                category: .shopping
            ),
            TaskDraft(
                title: "Call dentist",
                dueDate: nextWeek,
                priority: .low,
                category: .health
            ),
            TaskDraft(
                title: "Finish the report",
                dueDate: Calendar.current.date(byAdding: .day, value: 5, to: fixedNow),
                priority: .high,
                category: .work
            ),
        ]
    }
}
