import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow

/// Base class for snapshot tests providing consistent configuration and helpers.
///
/// Uses a fixed viewport (iPhone 13 Pro, 375×812) so images are identical
/// regardless of the local simulator (iPhone 17 Pro) or CI simulator (iPhone 16 Pro).
///
/// Reference images are recorded on CI (via `SNAPSHOT_RECORD` env var) to avoid
/// cross-environment rendering differences between local macOS and CI runners.
@MainActor
class SnapshotTestCase: XCTestCase {

    /// Set `isRecording = true` locally (or via `SNAPSHOT_RECORD` env var) to regenerate
    /// reference images. CI records on demand via workflow dispatch.
    override func setUp() {
        super.setUp()
//        isRecording = true
        if ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "true" {
            isRecording = true
        }
    }

    // MARK: - Helpers

    /// Snapshot a view in both light and dark mode using a fixed iPhone 13 Pro viewport.
    func assertLightAndDarkSnapshot<V: View>(
        of view: V,
        named name: String,
        precision: Float = 0.99,
        perceptualPrecision: Float = 0.98,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let lightView = view
            .environment(\.colorScheme, .light)

        let darkView = view
            .environment(\.colorScheme, .dark)

        assertSnapshot(
            of: UIHostingController(rootView: lightView),
            as: .image(on: .iPhone13Pro, precision: precision, perceptualPrecision: perceptualPrecision),
            named: "\(name)-light",
            file: file,
            testName: testName,
            line: line
        )

        assertSnapshot(
            of: UIHostingController(rootView: darkView),
            as: .image(on: .iPhone13Pro, precision: precision, perceptualPrecision: perceptualPrecision),
            named: "\(name)-dark",
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Snapshot a view at two Dynamic Type sizes for accessibility testing.
    func assertAccessibilitySnapshot<V: View>(
        of view: V,
        named name: String,
        precision: Float = 0.99,
        perceptualPrecision: Float = 0.98,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let extraLargeView = view
            .environment(\.dynamicTypeSize, .xxxLarge)

        assertSnapshot(
            of: UIHostingController(rootView: extraLargeView),
            as: .image(on: .iPhone13Pro, precision: precision, perceptualPrecision: perceptualPrecision),
            named: "\(name)-xxxLarge",
            file: file,
            testName: testName,
            line: line
        )

        let accessibilityView = view
            .environment(\.dynamicTypeSize, .accessibility3)

        assertSnapshot(
            of: UIHostingController(rootView: accessibilityView),
            as: .image(on: .iPhone13Pro, precision: precision, perceptualPrecision: perceptualPrecision),
            named: "\(name)-accessibility3",
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Wrap a view with the standard environment required by most Lazyflow views.
    func wrapInEnvironment<V: View>(_ view: V) -> some View {
        view.environment(FocusSessionCoordinator())
    }

    /// Wrap a view in a NavigationStack with standard environment.
    func wrapInNavigation<V: View>(_ view: V) -> some View {
        NavigationStack {
            view
        }
        .environment(FocusSessionCoordinator())
    }
}
