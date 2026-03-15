import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow
import LazyflowCore

final class DataAboutSettingsSnapshotTests: SnapshotTestCase {

    func testDefaultState() {
        let view = wrapInNavigation(DataAboutSettingsView())
        assertLightAndDarkSnapshot(of: view, named: "default")
    }

    func testAccessibility() {
        let view = wrapInNavigation(DataAboutSettingsView())
        assertAccessibilitySnapshot(of: view, named: "data_about_settings")
    }

    // MARK: - iPad

    func testDefaultStateIPad() {
        let view = wrapInNavigation(DataAboutSettingsView())
        assertLightAndDarkSnapshotIPad(of: view, named: "default")
    }

    func testAccessibilityIPad() {
        let view = wrapInNavigation(DataAboutSettingsView())
        assertAccessibilitySnapshotIPad(of: view, named: "data_about_settings")
    }
}
