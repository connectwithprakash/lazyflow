import XCTest
import SwiftUI
@testable import Taskweave

final class TaskweaveTests: XCTestCase {

    override func setUpWithError() throws {
        // Reset test environment before each test
    }

    override func tearDownWithError() throws {
        // Clean up after each test
    }

    // MARK: - Task Model Tests

    func testTaskCreation() throws {
        let task = Task(title: "Test Task")

        XCTAssertFalse(task.id.uuidString.isEmpty)
        XCTAssertEqual(task.title, "Test Task")
        XCTAssertNil(task.notes)
        XCTAssertNil(task.dueDate)
        XCTAssertFalse(task.isCompleted)
        XCTAssertFalse(task.isArchived)
        XCTAssertEqual(task.priority, .none)
    }

    func testTaskCompletion() throws {
        let task = Task(title: "Test Task")
        let completedTask = task.completed()

        XCTAssertTrue(completedTask.isCompleted)
        XCTAssertNotNil(completedTask.completedAt)
    }

    func testTaskUncompletion() throws {
        let task = Task(title: "Test Task", isCompleted: true, completedAt: Date())
        let uncompletedTask = task.uncompleted()

        XCTAssertFalse(uncompletedTask.isCompleted)
        XCTAssertNil(uncompletedTask.completedAt)
    }

    func testTaskIsDueToday() throws {
        let taskDueToday = Task(title: "Today Task", dueDate: Date())
        let taskDueTomorrow = Task(title: "Tomorrow Task", dueDate: Date().addingDays(1))
        let taskNoDueDate = Task(title: "No Date Task")

        XCTAssertTrue(taskDueToday.isDueToday)
        XCTAssertFalse(taskDueTomorrow.isDueToday)
        XCTAssertFalse(taskNoDueDate.isDueToday)
    }

    func testTaskIsOverdue() throws {
        let overdueTask = Task(title: "Overdue Task", dueDate: Date().addingDays(-2))
        let todayTask = Task(title: "Today Task", dueDate: Date())
        let completedOverdueTask = Task(title: "Completed", dueDate: Date().addingDays(-2), isCompleted: true)

        XCTAssertTrue(overdueTask.isOverdue)
        XCTAssertFalse(todayTask.isOverdue)
        XCTAssertFalse(completedOverdueTask.isOverdue)
    }

    // MARK: - Priority Tests

    func testPriorityOrder() throws {
        XCTAssertLessThan(Priority.urgent.sortOrder, Priority.high.sortOrder)
        XCTAssertLessThan(Priority.high.sortOrder, Priority.medium.sortOrder)
        XCTAssertLessThan(Priority.medium.sortOrder, Priority.low.sortOrder)
        XCTAssertLessThan(Priority.low.sortOrder, Priority.none.sortOrder)
    }

    // MARK: - TaskList Tests

    func testTaskListCreation() throws {
        let list = TaskList(name: "Work")

        XCTAssertFalse(list.id.uuidString.isEmpty)
        XCTAssertEqual(list.name, "Work")
        XCTAssertEqual(list.colorHex, "#218A8D")
        XCTAssertFalse(list.isDefault)
    }

    // MARK: - RecurringRule Tests

    func testRecurringRuleDailyNextOccurrence() throws {
        let rule = RecurringRule(frequency: .daily, interval: 1)
        let startDate = Date()

        let nextDate = rule.nextOccurrence(from: startDate)

        XCTAssertNotNil(nextDate)
        XCTAssertEqual(Calendar.current.dateComponents([.day], from: startDate, to: nextDate!).day, 1)
    }

    func testRecurringRuleWeeklyNextOccurrence() throws {
        let rule = RecurringRule(frequency: .weekly, interval: 1)
        let startDate = Date()

        let nextDate = rule.nextOccurrence(from: startDate)

        XCTAssertNotNil(nextDate)
        XCTAssertEqual(Calendar.current.dateComponents([.weekOfYear], from: startDate, to: nextDate!).weekOfYear, 1)
    }

    func testRecurringRuleWithEndDate() throws {
        let pastEndDate = Date().addingDays(-1)
        let rule = RecurringRule(frequency: .daily, interval: 1, endDate: pastEndDate)

        let nextDate = rule.nextOccurrence(from: Date())

        XCTAssertNil(nextDate)
    }

    // MARK: - Date Extension Tests

    func testDateIsToday() throws {
        XCTAssertTrue(Date().isToday)
        XCTAssertFalse(Date().addingDays(1).isToday)
        XCTAssertFalse(Date().addingDays(-1).isToday)
    }

    func testDateIsTomorrow() throws {
        XCTAssertTrue(Date().addingDays(1).isTomorrow)
        XCTAssertFalse(Date().isTomorrow)
    }

    func testDateAddingDays() throws {
        let today = Date()
        let tomorrow = today.addingDays(1)

        let daysDifference = Calendar.current.dateComponents([.day], from: today, to: tomorrow).day

        XCTAssertEqual(daysDifference, 1)
    }

    // MARK: - Color Extension Tests

    func testColorFromHex() throws {
        let color = Color(hex: "#218A8D")
        XCTAssertNotNil(color)

        let colorWithoutHash = Color(hex: "218A8D")
        XCTAssertNotNil(colorWithoutHash)

        let invalidColor = Color(hex: "invalid")
        XCTAssertNil(invalidColor)
    }

    // MARK: - Performance Tests

    func testTaskCreationPerformance() throws {
        measure {
            for _ in 0..<1000 {
                _ = Task(title: "Performance Test Task")
            }
        }
    }

    // MARK: - Time Protection Tests

    func testTimeProtectionRuleCreation() throws {
        let rule = TimeProtectionRule(
            name: "Lunch Break",
            type: .lunch,
            startHour: 12,
            startMinute: 0,
            endHour: 13,
            endMinute: 0,
            daysOfWeek: [2, 3, 4, 5, 6],
            isActive: true
        )

        XCTAssertEqual(rule.name, "Lunch Break")
        XCTAssertEqual(rule.type, .lunch)
        XCTAssertTrue(rule.isActive)
    }

    func testConflictSeverityComparison() throws {
        XCTAssertTrue(ConflictSeverity.high.rawValue > ConflictSeverity.medium.rawValue)
        XCTAssertTrue(ConflictSeverity.medium.rawValue > ConflictSeverity.low.rawValue)
    }

    // MARK: - v0.9.0 iPad Optimization Tests

    func testNotificationNamesExist() throws {
        // Test that notification names for keyboard shortcuts are defined
        XCTAssertEqual(Notification.Name.newTaskShortcut.rawValue, "newTaskShortcut")
        XCTAssertEqual(Notification.Name.searchShortcut.rawValue, "searchShortcut")
        XCTAssertEqual(Notification.Name.navigateToTab.rawValue, "navigateToTab")
    }

    func testNotificationPosting() throws {
        // Test that notifications can be posted without crashing
        let expectation = XCTestExpectation(description: "Notification received")

        let observer = NotificationCenter.default.addObserver(
            forName: .newTaskShortcut,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        NotificationCenter.default.post(name: .newTaskShortcut, object: nil)

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testNavigateToTabNotification() throws {
        // Test that navigate to tab notification works with payload
        let expectation = XCTestExpectation(description: "Tab navigation notification received")
        var receivedTab: String?

        let observer = NotificationCenter.default.addObserver(
            forName: .navigateToTab,
            object: nil,
            queue: .main
        ) { notification in
            receivedTab = notification.object as? String
            expectation.fulfill()
        }

        NotificationCenter.default.post(name: .navigateToTab, object: "calendar")

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedTab, "calendar")
        NotificationCenter.default.removeObserver(observer)
    }
}
