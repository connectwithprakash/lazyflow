import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow
import LazyflowCore

final class GeneralSettingsSnapshotTests: SnapshotTestCase {

    func testDefaultState() {
        let view = wrapInNavigation(GeneralSettingsView())
        assertLightAndDarkSnapshot(of: view, named: "default")
    }

    func testAccessibility() {
        let view = wrapInNavigation(GeneralSettingsView())
        assertAccessibilitySnapshot(of: view, named: "general_settings")
    }

    // MARK: - iPad

    func testDefaultStateIPad() {
        let view = wrapInNavigation(GeneralSettingsView())
        assertLightAndDarkSnapshotIPad(of: view, named: "default")
    }

    func testAccessibilityIPad() {
        let view = wrapInNavigation(GeneralSettingsView())
        assertAccessibilitySnapshotIPad(of: view, named: "general_settings")
    }
}
