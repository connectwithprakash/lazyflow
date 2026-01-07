import XCTest
@testable import Lazyflow

final class ConflictDetectionServiceTests: XCTestCase {

    // MARK: - Overlap Calculation Tests

    func testCalculateOverlap_NoOverlap() {
        let start1 = Date()
        let end1 = start1.addingTimeInterval(3600) // 1 hour
        let start2 = end1.addingTimeInterval(1800) // 30 min after end1
        let end2 = start2.addingTimeInterval(3600)

        let overlap = calculateOverlap(start1: start1, end1: end1, start2: start2, end2: end2)
        XCTAssertEqual(overlap, 0)
    }

    func testCalculateOverlap_PartialOverlap() {
        let start1 = Date()
        let end1 = start1.addingTimeInterval(3600) // 1 hour
        let start2 = start1.addingTimeInterval(1800) // Starts 30 min into first
        let end2 = start2.addingTimeInterval(3600)

        let overlap = calculateOverlap(start1: start1, end1: end1, start2: start2, end2: end2)
        XCTAssertEqual(overlap, 1800) // 30 minutes overlap
    }

    func testCalculateOverlap_FullContainment() {
        let start1 = Date()
        let end1 = start1.addingTimeInterval(7200) // 2 hours
        let start2 = start1.addingTimeInterval(1800) // 30 min in
        let end2 = start2.addingTimeInterval(1800) // 30 min duration (fully inside)

        let overlap = calculateOverlap(start1: start1, end1: end1, start2: start2, end2: end2)
        XCTAssertEqual(overlap, 1800) // Full inner duration
    }

    func testCalculateOverlap_Identical() {
        let start = Date()
        let end = start.addingTimeInterval(3600)

        let overlap = calculateOverlap(start1: start, end1: end, start2: start, end2: end)
        XCTAssertEqual(overlap, 3600) // Full overlap
    }

    func testCalculateOverlap_TouchingButNoOverlap() {
        let start1 = Date()
        let end1 = start1.addingTimeInterval(3600)
        let start2 = end1 // Starts exactly when first ends
        let end2 = start2.addingTimeInterval(3600)

        let overlap = calculateOverlap(start1: start1, end1: end1, start2: start2, end2: end2)
        XCTAssertEqual(overlap, 0)
    }

    // MARK: - ConflictSeverity Tests

    func testConflictSeverity_Comparison() {
        XCTAssertTrue(ConflictSeverity.high > ConflictSeverity.medium)
        XCTAssertTrue(ConflictSeverity.medium > ConflictSeverity.low)
        XCTAssertFalse(ConflictSeverity.low > ConflictSeverity.medium)
    }

    func testConflictSeverity_DisplayName() {
        XCTAssertEqual(ConflictSeverity.low.displayName, "Low")
        XCTAssertEqual(ConflictSeverity.medium.displayName, "Medium")
        XCTAssertEqual(ConflictSeverity.high.displayName, "High")
    }

    func testConflictSeverity_Color() {
        XCTAssertEqual(ConflictSeverity.low.color, "yellow")
        XCTAssertEqual(ConflictSeverity.medium.color, "orange")
        XCTAssertEqual(ConflictSeverity.high.color, "red")
    }

    func testConflictSeverity_SystemImage() {
        XCTAssertEqual(ConflictSeverity.low.systemImage, "exclamationmark.circle")
        XCTAssertEqual(ConflictSeverity.medium.systemImage, "exclamationmark.triangle")
        XCTAssertEqual(ConflictSeverity.high.systemImage, "exclamationmark.octagon")
    }

    // MARK: - TaskConflict Tests

    func testTaskConflict_FormattedOverlap_Minutes() {
        let task = Task(title: "Test")
        let conflict = TaskConflict(
            id: UUID(),
            task: task,
            conflictTime: Date(),
            overlapDuration: 900, // 15 minutes
            severity: .medium,
            type: .calendarEvent
        )
        XCTAssertEqual(conflict.formattedOverlap, "15m overlap")
    }

    func testTaskConflict_FormattedOverlap_Hours() {
        let task = Task(title: "Test")
        let conflict = TaskConflict(
            id: UUID(),
            task: task,
            conflictTime: Date(),
            overlapDuration: 3600, // 1 hour
            severity: .high,
            type: .calendarEvent
        )
        XCTAssertEqual(conflict.formattedOverlap, "1h overlap")
    }

    func testTaskConflict_FormattedOverlap_HoursAndMinutes() {
        let task = Task(title: "Test")
        let conflict = TaskConflict(
            id: UUID(),
            task: task,
            conflictTime: Date(),
            overlapDuration: 5400, // 1.5 hours
            severity: .high,
            type: .calendarEvent
        )
        XCTAssertEqual(conflict.formattedOverlap, "1h 30m overlap")
    }

    func testTaskConflict_Description_CalendarEvent() {
        let task = Task(title: "Test")
        let conflict = TaskConflict(
            id: UUID(),
            task: task,
            conflictingEvent: nil,
            conflictTime: Date(),
            overlapDuration: 1800,
            severity: .medium,
            type: .calendarEvent
        )
        XCTAssertTrue(conflict.conflictDescription.contains("calendar event"))
    }

    func testTaskConflict_Description_TaskOverlap() {
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        let conflict = TaskConflict(
            id: UUID(),
            task: task1,
            conflictingTask: task2,
            conflictTime: Date(),
            overlapDuration: 1800,
            severity: .medium,
            type: .taskOverlap
        )
        XCTAssertTrue(conflict.conflictDescription.contains("Task 2"))
    }

    func testTaskConflict_Description_NewMeeting() {
        let task = Task(title: "Test")
        let conflict = TaskConflict(
            id: UUID(),
            task: task,
            conflictTime: Date(),
            overlapDuration: 1800,
            severity: .high,
            type: .newMeeting
        )
        XCTAssertTrue(conflict.conflictDescription.contains("New meeting"))
    }

    // MARK: - ConflictType Tests

    func testConflictType_AllCases() {
        // Verify we have all expected types
        let calendarType: ConflictType = .calendarEvent
        let taskType: ConflictType = .taskOverlap
        let meetingType: ConflictType = .newMeeting

        // Each should create different conflict descriptions
        let task = Task(title: "Test")

        let calendarConflict = TaskConflict(id: UUID(), task: task, conflictTime: Date(), overlapDuration: 0, severity: .low, type: calendarType)
        let taskConflict = TaskConflict(id: UUID(), task: task, conflictTime: Date(), overlapDuration: 0, severity: .low, type: taskType)
        let meetingConflict = TaskConflict(id: UUID(), task: task, conflictTime: Date(), overlapDuration: 0, severity: .low, type: meetingType)

        XCTAssertNotEqual(calendarConflict.conflictDescription, taskConflict.conflictDescription)
        XCTAssertNotEqual(taskConflict.conflictDescription, meetingConflict.conflictDescription)
    }

    // MARK: - Severity Calculation Tests

    func testCalculateSeverity_SignificantOverlap_ReturnsHigh() {
        // 60% overlap
        let severity = calculateSeverity(overlap: 3600, taskDuration: 6000)
        XCTAssertEqual(severity, .high)
    }

    func testCalculateSeverity_ModerateOverlap_ReturnsMedium() {
        // 30% overlap
        let severity = calculateSeverity(overlap: 1800, taskDuration: 6000)
        XCTAssertEqual(severity, .medium)
    }

    func testCalculateSeverity_MinimalOverlap_ReturnsLow() {
        // 10% overlap
        let severity = calculateSeverity(overlap: 600, taskDuration: 6000)
        XCTAssertEqual(severity, .low)
    }

    // MARK: - Helper Methods

    private func calculateOverlap(start1: Date, end1: Date, start2: Date, end2: Date) -> TimeInterval {
        let overlapStart = max(start1, start2)
        let overlapEnd = min(end1, end2)
        return max(0, overlapEnd.timeIntervalSince(overlapStart))
    }

    private func calculateSeverity(overlap: TimeInterval, taskDuration: TimeInterval) -> ConflictSeverity {
        let overlapPercentage = overlap / taskDuration

        if overlapPercentage > 0.5 {
            return .high
        } else if overlapPercentage > 0.25 {
            return .medium
        }
        return .low
    }
}
