import XCTest
@testable import Lazyflow

final class EventPreferenceLearningServiceTests: XCTestCase {
    var service: EventPreferenceLearningService!
    var testDefaults: UserDefaults!

    override func setUpWithError() throws {
        testDefaults = UserDefaults(suiteName: "EventPreferenceLearningTests")!
        testDefaults.removePersistentDomain(forName: "EventPreferenceLearningTests")
        service = EventPreferenceLearningService(defaults: testDefaults)
    }

    override func tearDownWithError() throws {
        service.clearAllLearningData()
        testDefaults.removePersistentDomain(forName: "EventPreferenceLearningTests")
        testDefaults = nil
        service = nil
    }

    // MARK: - Helper

    private func makeEvent(
        title: String,
        isAllDay: Bool = false,
        isSelected: Bool = true
    ) -> PlanEventItem {
        let now = Date()
        return PlanEventItem(
            id: UUID().uuidString,
            title: title,
            startDate: now,
            endDate: now.addingTimeInterval(3600),
            isAllDay: isAllDay,
            isSelected: isSelected
        )
    }

    // MARK: - Title Normalization

    func testNormalizeTitle_Lowercases() {
        XCTAssertEqual(
            EventPreferenceLearningService.normalizeTitle("Team STANDUP"),
            "team standup"
        )
    }

    func testNormalizeTitle_TrimsWhitespace() {
        XCTAssertEqual(
            EventPreferenceLearningService.normalizeTitle("  Standup  "),
            "standup"
        )
    }

    func testNormalizeTitle_CaseInsensitiveLookup() {
        let events = [makeEvent(title: "STANDUP", isSelected: false)]
        service.recordSelections(events)

        XCTAssertNotNil(service.preference(for: "standup"))
        XCTAssertNotNil(service.preference(for: "STANDUP"))
        XCTAssertNotNil(service.preference(for: "Standup"))
    }

    // MARK: - Recording Selections

    func testRecordSelections_CreatesRecords() {
        let events = [
            makeEvent(title: "Standup", isSelected: true),
            makeEvent(title: "Lunch", isSelected: false),
        ]
        service.recordSelections(events)

        XCTAssertEqual(service.records.count, 2)
    }

    func testRecordSelections_UpdatesPreferences() {
        let events = [makeEvent(title: "Standup", isSelected: true)]
        service.recordSelections(events)

        let pref = service.preference(for: "Standup")
        XCTAssertNotNil(pref)
        XCTAssertEqual(pref?.selectedCount, 1)
        XCTAssertEqual(pref?.skippedCount, 0)
    }

    func testRecordSelections_AccumulatesOverMultipleSessions() {
        // Session 1: selected
        service.recordSelections([makeEvent(title: "Standup", isSelected: true)])
        // Session 2: skipped
        service.recordSelections([makeEvent(title: "Standup", isSelected: false)])
        // Session 3: selected
        service.recordSelections([makeEvent(title: "Standup", isSelected: true)])

        let pref = service.preference(for: "Standup")
        XCTAssertEqual(pref?.selectedCount, 2)
        XCTAssertEqual(pref?.skippedCount, 1)
        XCTAssertEqual(pref?.totalCount, 3)
    }

    func testRecordSelections_IgnoresEmptyTitles() {
        let events = [makeEvent(title: "", isSelected: true)]
        service.recordSelections(events)

        XCTAssertEqual(service.records.count, 0)
        XCTAssertTrue(service.preferences.isEmpty)
    }

    // MARK: - Threshold Tests

    func testIsFrequentlySkipped_RequiresThreeInteractions() {
        // Only 2 interactions: not enough data
        service.recordSelections([makeEvent(title: "Standup", isSelected: false)])
        service.recordSelections([makeEvent(title: "Standup", isSelected: false)])

        XCTAssertFalse(service.isFrequentlySkipped("Standup"))

        // 3rd interaction: now has enough data with 100% skip rate
        service.recordSelections([makeEvent(title: "Standup", isSelected: false)])

        XCTAssertTrue(service.isFrequentlySkipped("Standup"))
    }

    func testIsFrequentlySkipped_RequiresHighSkipRate() {
        // 3 interactions: 2 skips, 1 select = 66% skip rate (below 80%)
        service.recordSelections([makeEvent(title: "Review", isSelected: false)])
        service.recordSelections([makeEvent(title: "Review", isSelected: false)])
        service.recordSelections([makeEvent(title: "Review", isSelected: true)])

        XCTAssertFalse(service.isFrequentlySkipped("Review"))
    }

    func testIsFrequentlySelected_RequiresHighSelectionRate() {
        // 4 interactions: 4 selects = 100% selection rate
        for _ in 0..<4 {
            service.recordSelections([makeEvent(title: "Sprint Planning", isSelected: true)])
        }

        XCTAssertTrue(service.isFrequentlySelected("Sprint Planning"))
        XCTAssertFalse(service.isFrequentlySkipped("Sprint Planning"))
    }

    func testIsFrequentlySelected_NotEnoughData() {
        service.recordSelections([makeEvent(title: "Planning", isSelected: true)])
        service.recordSelections([makeEvent(title: "Planning", isSelected: true)])

        XCTAssertFalse(service.isFrequentlySelected("Planning"))
    }

    // MARK: - Skip/Selection Rate

    func testSkipRate_CalculatesCorrectly() {
        service.recordSelections([makeEvent(title: "Lunch", isSelected: false)])
        service.recordSelections([makeEvent(title: "Lunch", isSelected: false)])
        service.recordSelections([makeEvent(title: "Lunch", isSelected: false)])
        service.recordSelections([makeEvent(title: "Lunch", isSelected: true)])

        let pref = service.preference(for: "Lunch")!
        XCTAssertEqual(pref.skipRate, 0.75, accuracy: 0.01)
        XCTAssertEqual(pref.selectionRate, 0.25, accuracy: 0.01)
    }

    // MARK: - Clear Data

    func testClearAllLearningData_RemovesEverything() {
        service.recordSelections([
            makeEvent(title: "Standup", isSelected: false),
            makeEvent(title: "Planning", isSelected: true),
        ])

        XCTAssertFalse(service.records.isEmpty)
        XCTAssertFalse(service.preferences.isEmpty)

        service.clearAllLearningData()

        XCTAssertTrue(service.records.isEmpty)
        XCTAssertTrue(service.preferences.isEmpty)
    }

    // MARK: - Max Record Limit

    func testRecordLimit_TrimsOldRecords() {
        // Record 510 events (over the 500 limit)
        for i in 0..<510 {
            service.recordSelections([makeEvent(title: "Event \(i)", isSelected: true)])
        }

        XCTAssertLessThanOrEqual(service.records.count, 500)
    }

    // MARK: - Persistence

    func testPersistence_SurvivesReload() {
        service.recordSelections([makeEvent(title: "Standup", isSelected: false)])
        service.recordSelections([makeEvent(title: "Standup", isSelected: false)])
        service.recordSelections([makeEvent(title: "Standup", isSelected: false)])

        // Create new service instance with same defaults (simulates app restart)
        let reloadedService = EventPreferenceLearningService(defaults: testDefaults)

        XCTAssertEqual(reloadedService.records.count, 3)
        XCTAssertTrue(reloadedService.isFrequentlySkipped("Standup"))
    }
}
