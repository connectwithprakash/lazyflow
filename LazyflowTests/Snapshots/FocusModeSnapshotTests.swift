import SwiftUI
import XCTest
import LazyflowCore
@testable import Lazyflow

/// Snapshot coverage for FocusModeView's portrait and landscape compositions (#297).
@MainActor
final class FocusModeSnapshotTests: SnapshotTestCase {

    private func makeFocusView() -> some View {
        let task = LazyflowCore.Task(
            title: "Write the launch announcement",
            notes: "Cover the headline features and link the changelog.",
            dueDate: SnapshotFixtures.fixedNow,
            estimatedDuration: 30 * 60
        )
        let mockService = MockTaskService()
        mockService.tasks = [task]
        let coordinator = FocusSessionCoordinator(taskService: mockService)
        coordinator.focusTaskID = task.id

        return FocusModeView()
            .environment(coordinator)
    }

    func testPortrait() {
        assertLightAndDarkSnapshot(of: makeFocusView(), named: "focus-mode")
    }

    func testLandscape() {
        assertLandscapeSnapshot(of: makeFocusView(), named: "focus-mode")
    }
}
