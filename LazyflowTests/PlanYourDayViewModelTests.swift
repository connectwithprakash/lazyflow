import XCTest
@testable import Lazyflow

@MainActor
final class PlanYourDayViewModelTests: XCTestCase {
    var viewModel: PlanYourDayViewModel!

    override func setUpWithError() throws {
        viewModel = PlanYourDayViewModel()
    }

    override func tearDownWithError() throws {
        viewModel = nil
    }

    // MARK: - Helper

    private func makeSampleEvents() -> [PlanEventItem] {
        let now = Date()
        let calendar = Calendar.current
        return [
            PlanEventItem(
                id: "event-1",
                title: "Team Standup",
                startDate: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!,
                endDate: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: now)!,
                isAllDay: false,
                isSelected: true
            ),
            PlanEventItem(
                id: "event-2",
                title: "Design Review",
                startDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now)!,
                endDate: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: now)!,
                isAllDay: false,
                isSelected: true
            ),
            PlanEventItem(
                id: "event-3",
                title: "Company Holiday",
                startDate: calendar.startOfDay(for: now),
                endDate: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!,
                isAllDay: true,
                isSelected: false
            ),
        ]
    }

    // MARK: - Initial State

    func testInitialState_IsLoading() {
        XCTAssertTrue(viewModel.events.isEmpty)
        XCTAssertEqual(viewModel.selectedCount, 0)
        XCTAssertTrue(viewModel.noneSelected)
        XCTAssertFalse(viewModel.allSelected)
    }

    // MARK: - Selection Toggle

    func testToggleSelection_TogglesEvent() {
        viewModel.events = makeSampleEvents()

        // event-1 starts as selected
        XCTAssertTrue(viewModel.events[0].isSelected)

        viewModel.toggleSelection(for: "event-1")
        XCTAssertFalse(viewModel.events[0].isSelected)

        viewModel.toggleSelection(for: "event-1")
        XCTAssertTrue(viewModel.events[0].isSelected)
    }

    func testToggleSelection_NonexistentID_NoChange() {
        viewModel.events = makeSampleEvents()
        let selectedBefore = viewModel.selectedCount

        viewModel.toggleSelection(for: "nonexistent")

        XCTAssertEqual(viewModel.selectedCount, selectedBefore)
    }

    // MARK: - Select All / Deselect All

    func testSelectAll_SelectsAllEvents() {
        viewModel.events = makeSampleEvents()

        viewModel.selectAll()

        XCTAssertTrue(viewModel.allSelected)
        XCTAssertEqual(viewModel.selectedCount, 3)
    }

    func testDeselectAll_DeselectsAllEvents() {
        viewModel.events = makeSampleEvents()

        viewModel.deselectAll()

        XCTAssertTrue(viewModel.noneSelected)
        XCTAssertEqual(viewModel.selectedCount, 0)
    }

    // MARK: - Computed Properties

    func testSelectedEvents_ReturnsOnlySelected() {
        viewModel.events = makeSampleEvents()

        let selected = viewModel.selectedEvents
        // event-1 and event-2 are selected, event-3 (all-day) is not
        XCTAssertEqual(selected.count, 2)
        XCTAssertTrue(selected.contains(where: { $0.id == "event-1" }))
        XCTAssertTrue(selected.contains(where: { $0.id == "event-2" }))
    }

    func testTimedEvents_ExcludesAllDay() {
        viewModel.events = makeSampleEvents()

        XCTAssertEqual(viewModel.timedEvents.count, 2)
        XCTAssertTrue(viewModel.timedEvents.allSatisfy { !$0.isAllDay })
    }

    func testAllDayEvents_OnlyAllDay() {
        viewModel.events = makeSampleEvents()

        XCTAssertEqual(viewModel.allDayEvents.count, 1)
        XCTAssertEqual(viewModel.allDayEvents.first?.title, "Company Holiday")
    }

    // MARK: - Estimated Time

    func testTotalEstimatedMinutes_SumsSelectedEvents() {
        viewModel.events = makeSampleEvents()

        // event-1: 30 min, event-2: 60 min (both selected), event-3: all-day (not selected)
        XCTAssertEqual(viewModel.totalEstimatedMinutes, 90)
    }

    func testFormattedEstimatedTime_LessThanHour() {
        let now = Date()
        let calendar = Calendar.current
        viewModel.events = [
            PlanEventItem(
                id: "short",
                title: "Quick Call",
                startDate: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!,
                endDate: calendar.date(bySettingHour: 10, minute: 15, second: 0, of: now)!,
                isAllDay: false,
                isSelected: true
            ),
        ]

        XCTAssertEqual(viewModel.formattedEstimatedTime, "15m")
    }

    func testFormattedEstimatedTime_MoreThanHour() {
        viewModel.events = makeSampleEvents()

        // 90 min = 1h 30m
        XCTAssertEqual(viewModel.formattedEstimatedTime, "1h 30m")
    }

    func testFormattedEstimatedTime_ZeroWhenNoneSelected() {
        viewModel.events = makeSampleEvents()
        viewModel.deselectAll()

        XCTAssertEqual(viewModel.formattedEstimatedTime, "0m")
    }

    // MARK: - No-op on Empty Selection

    func testCreateTasks_NoSelection_NoStateChange() {
        viewModel.events = makeSampleEvents()
        viewModel.deselectAll()
        viewModel.viewState = .selection

        viewModel.createTasks()

        // Should remain in selection state since no events are selected
        if case .selection = viewModel.viewState {
            // Expected
        } else {
            XCTFail("Expected viewState to remain .selection when no events selected")
        }
    }
}

// MARK: - PlanEventItem Tests

final class PlanEventItemTests: XCTestCase {

    // MARK: - isLikelyNonTask Detection

    func testIsLikelyNonTask_AllDay_ReturnsTrue() {
        let item = PlanEventItem(
            title: "Normal Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: true,
            isSelected: false
        )
        XCTAssertTrue(item.isLikelyNonTask)
    }

    func testIsLikelyNonTask_LunchBreak_ReturnsTrue() {
        let item = PlanEventItem(
            title: "Lunch Break",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isSelected: true
        )
        XCTAssertTrue(item.isLikelyNonTask)
    }

    func testIsLikelyNonTask_OutOfOffice_ReturnsTrue() {
        let item = PlanEventItem(
            title: "Out of Office",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isSelected: true
        )
        XCTAssertTrue(item.isLikelyNonTask)
    }

    func testIsLikelyNonTask_FocusTime_ReturnsTrue() {
        let item = PlanEventItem(
            title: "Focus Time",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isSelected: true
        )
        XCTAssertTrue(item.isLikelyNonTask)
    }

    func testIsLikelyNonTask_RegularMeeting_ReturnsFalse() {
        let item = PlanEventItem(
            title: "Sprint Planning",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isSelected: true
        )
        XCTAssertFalse(item.isLikelyNonTask)
    }

    // MARK: - Duration Formatting

    func testFormattedDuration_ShortEvent() {
        let item = PlanEventItem(
            title: "Quick Sync",
            startDate: Date(),
            endDate: Date().addingTimeInterval(15 * 60),
            isSelected: true
        )
        XCTAssertEqual(item.formattedDuration, "15m")
    }

    func testFormattedDuration_LongEvent() {
        let item = PlanEventItem(
            title: "Workshop",
            startDate: Date(),
            endDate: Date().addingTimeInterval(90 * 60),
            isSelected: true
        )
        XCTAssertEqual(item.formattedDuration, "1h 30m")
    }

    func testFormattedDuration_ExactHour() {
        let item = PlanEventItem(
            title: "Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(60 * 60),
            isSelected: true
        )
        XCTAssertEqual(item.formattedDuration, "1h")
    }

    func testFormattedDuration_AllDay() {
        let item = PlanEventItem(
            title: "Holiday",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            isAllDay: true,
            isSelected: false
        )
        XCTAssertEqual(item.formattedDuration, "All day")
    }
}

// MARK: - PlanYourDayResult Tests

final class PlanYourDayResultTests: XCTestCase {

    func testSummaryText_SingleTask() {
        let result = PlanYourDayResult(tasksCreated: 1, totalEstimatedMinutes: 30, createdAt: Date())
        XCTAssertEqual(result.summaryText, "1 task added to your day")
    }

    func testSummaryText_MultipleTasks() {
        let result = PlanYourDayResult(tasksCreated: 5, totalEstimatedMinutes: 180, createdAt: Date())
        XCTAssertEqual(result.summaryText, "5 tasks added to your day")
    }

    func testFormattedTotalTime_LessThanHour() {
        let result = PlanYourDayResult(tasksCreated: 2, totalEstimatedMinutes: 45, createdAt: Date())
        XCTAssertEqual(result.formattedTotalTime, "45m")
    }

    func testFormattedTotalTime_MoreThanHour() {
        let result = PlanYourDayResult(tasksCreated: 3, totalEstimatedMinutes: 150, createdAt: Date())
        XCTAssertEqual(result.formattedTotalTime, "2h 30m")
    }

    func testFormattedTotalTime_ExactHours() {
        let result = PlanYourDayResult(tasksCreated: 4, totalEstimatedMinutes: 120, createdAt: Date())
        XCTAssertEqual(result.formattedTotalTime, "2h")
    }
}
