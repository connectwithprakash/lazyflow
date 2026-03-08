import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow
import LazyflowCore

final class AddTaskViewSnapshotTests: SnapshotTestCase {

    func testEmptyForm() {
        let view = AddTaskView()
        assertLightAndDarkSnapshot(of: view, named: "emptyForm")
    }

    func testWithDefaultDate() {
        let view = AddTaskView(defaultDueDate: SnapshotFixtures.fixedNow)
        assertLightAndDarkSnapshot(of: view, named: "withDefaultDate")
    }

    func testAccessibility() {
        let view = AddTaskView()
        assertAccessibilitySnapshot(of: view, named: "addTask")
    }

    // MARK: - iPad

    func testEmptyFormIPad() {
        let view = AddTaskView()
        assertLightAndDarkSnapshotIPad(of: view, named: "emptyForm")
    }

    func testWithDefaultDateIPad() {
        let view = AddTaskView(defaultDueDate: SnapshotFixtures.fixedNow)
        assertLightAndDarkSnapshotIPad(of: view, named: "withDefaultDate")
    }

    func testAccessibilityIPad() {
        let view = AddTaskView()
        assertAccessibilitySnapshotIPad(of: view, named: "addTask")
    }
}
