import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow
import LazyflowCore

final class SettingsViewSnapshotTests: SnapshotTestCase {

    func testDefaultState() {
        let view = wrapInNavigation(SettingsView())
        assertLightAndDarkSnapshot(of: view, named: "default")
    }

    func testAccessibility() {
        let view = wrapInNavigation(SettingsView())
        assertAccessibilitySnapshot(of: view, named: "settings")
    }

    // MARK: - iPad

    func testDefaultStateIPad() {
        let view = wrapInNavigation(SettingsView())
        assertLightAndDarkSnapshotIPad(of: view, named: "default")
    }

    func testAccessibilityIPad() {
        let view = wrapInNavigation(SettingsView())
        assertAccessibilitySnapshotIPad(of: view, named: "settings")
    }
}
