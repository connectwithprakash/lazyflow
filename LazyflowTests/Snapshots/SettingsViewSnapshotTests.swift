import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow

final class SettingsViewSnapshotTests: SnapshotTestCase {

    func testDefaultState() {
        let view = wrapInNavigation(SettingsView())
        assertLightAndDarkSnapshot(of: view, named: "default")
    }

    func testAccessibility() {
        let view = wrapInNavigation(SettingsView())
        assertAccessibilitySnapshot(of: view, named: "settings")
    }
}
