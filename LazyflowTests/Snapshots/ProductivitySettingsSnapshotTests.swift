import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow
import LazyflowCore

final class ProductivitySettingsSnapshotTests: SnapshotTestCase {

    func testDefaultState() {
        let view = wrapInNavigation(ProductivitySettingsView())
        assertLightAndDarkSnapshot(of: view, named: "default")
    }

    func testAccessibility() {
        let view = wrapInNavigation(ProductivitySettingsView())
        assertAccessibilitySnapshot(of: view, named: "productivity_settings")
    }

    // MARK: - iPad

    func testDefaultStateIPad() {
        let view = wrapInNavigation(ProductivitySettingsView())
        assertLightAndDarkSnapshotIPad(of: view, named: "default")
    }

    func testAccessibilityIPad() {
        let view = wrapInNavigation(ProductivitySettingsView())
        assertAccessibilitySnapshotIPad(of: view, named: "productivity_settings")
    }
}
