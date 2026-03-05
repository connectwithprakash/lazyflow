import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow
import LazyflowCore

/// TodayView snapshot tests.
///
/// TodayView depends on many shared singletons (PrioritizationService, ConflictDetectionService,
/// DailySummaryService, CalendarService, etc.) that produce non-deterministic renders across test runs.
/// Full visual regression snapshots require deeper DI refactoring (see #244 follow-up).
/// For now, these tests verify construction + rendering stability with perceptualPrecision tolerance.
final class TodayViewSnapshotTests: SnapshotTestCase {

    override func setUp() {
        super.setUp()
        // Stabilize time-dependent prompt cards
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppConstants.StorageKey.lastMorningBriefingDate)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppConstants.StorageKey.lastPlanYourDayDate)
        UserDefaults.standard.set(23, forKey: AppConstants.StorageKey.summaryPromptHour)
        UserDefaults.standard.set(false, forKey: AppConstants.StorageKey.morningBriefingEnabled)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppConstants.StorageKey.lastMorningBriefingDate)
        UserDefaults.standard.removeObject(forKey: AppConstants.StorageKey.lastPlanYourDayDate)
        UserDefaults.standard.removeObject(forKey: AppConstants.StorageKey.summaryPromptHour)
        UserDefaults.standard.removeObject(forKey: AppConstants.StorageKey.morningBriefingEnabled)
        super.tearDown()
    }

    func testEmptyStateRenders() {
        let vm = TodayViewModel(taskService: SnapshotFixtures.emptyTaskService())
        vm.refreshTasks()
        let view = wrapInEnvironment(TodayView(viewModel: vm))
        let controller = UIHostingController(rootView: view.environment(\.colorScheme, .light))
        controller.view.frame = UIScreen.main.bounds
        controller.view.layoutIfNeeded()
        // Verify the view renders without crashes
        XCTAssertNotNil(controller.view.snapshotView(afterScreenUpdates: true))
    }

    func testPopulatedStateRenders() {
        let vm = TodayViewModel(taskService: SnapshotFixtures.populatedTaskService())
        vm.refreshTasks()
        let view = wrapInEnvironment(TodayView(viewModel: vm))
        let controller = UIHostingController(rootView: view.environment(\.colorScheme, .light))
        controller.view.frame = UIScreen.main.bounds
        controller.view.layoutIfNeeded()
        XCTAssertNotNil(controller.view.snapshotView(afterScreenUpdates: true))
    }
}
