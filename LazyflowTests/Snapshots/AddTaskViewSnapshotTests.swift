import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow

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
}
