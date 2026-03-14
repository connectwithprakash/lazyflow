import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow
import LazyflowCore

final class BriefingsSettingsSnapshotTests: SnapshotTestCase {

    func testDefaultState() {
        let view = wrapInNavigation(BriefingsSettingsView())
        assertLightAndDarkSnapshot(of: view, named: "default")
    }

    func testAccessibility() {
        let view = wrapInNavigation(BriefingsSettingsView())
        assertAccessibilitySnapshot(of: view, named: "briefings_settings")
    }

    // MARK: - iPad

    func testDefaultStateIPad() {
        let view = wrapInNavigation(BriefingsSettingsView())
        assertLightAndDarkSnapshotIPad(of: view, named: "default")
    }

    func testAccessibilityIPad() {
        let view = wrapInNavigation(BriefingsSettingsView())
        assertAccessibilitySnapshotIPad(of: view, named: "briefings_settings")
    }
}
