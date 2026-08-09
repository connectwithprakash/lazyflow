import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow
import LazyflowCore

final class UpcomingViewSnapshotTests: SnapshotTestCase {

    func testEmptyState() {
        let view = wrapInEnvironment(UpcomingView(taskService: SnapshotFixtures.emptyTaskService()))
        assertLightAndDarkSnapshot(of: view, named: "empty")
    }

    func testPopulatedState() {
        let view = wrapInEnvironment(UpcomingView(taskService: SnapshotFixtures.upcomingTaskService()))
        assertLightAndDarkSnapshot(of: view, named: "populated")
    }

    func testLandscape() {
        let view = wrapInEnvironment(UpcomingView(taskService: SnapshotFixtures.upcomingTaskService()))
        assertLandscapeSnapshot(of: view, named: "upcoming")
    }

    // MARK: - iPad

    func testEmptyStateIPad() {
        let view = wrapInEnvironment(UpcomingView(taskService: SnapshotFixtures.emptyTaskService()))
        assertLightAndDarkSnapshotIPad(of: view, named: "empty")
    }

    func testPopulatedStateIPad() {
        let view = wrapInEnvironment(UpcomingView(taskService: SnapshotFixtures.upcomingTaskService()))
        assertLightAndDarkSnapshotIPad(of: view, named: "populated")
    }
}
