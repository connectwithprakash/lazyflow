import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow
import LazyflowCore

/// Base class for snapshot tests providing consistent configuration and helpers.
///
/// Uses fixed viewports (iPhone 13 Pro 375×812, iPad Pro 12.9" 1024×1366) so images
/// are identical regardless of the local simulator or CI simulator.
///
/// References are recorded on CI to match the CI rendering environment.
/// Local mismatches are expected when Xcode versions differ.
/// To re-record, trigger the "Re-record Snapshots" CI workflow.
@MainActor
class SnapshotTestCase: XCTestCase {

    /// Wraps every test in `withSnapshotTesting` so the record mode applies
    /// to all assertions. Set `SNAPSHOT_RECORD=true` env var to re-record.
    override func invokeTest() {
        let record: SnapshotTestingConfiguration.Record =
            ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "true" ? .all : .missing
        withSnapshotTesting(record: record) {
            super.invokeTest()
        }
    }

    // MARK: - Device Detection

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    // MARK: - iPhone Helpers

    /// Snapshot a view in both light and dark mode using a fixed iPhone 13 Pro viewport.
    /// Automatically skips when running on iPad simulator.
    func assertLightAndDarkSnapshot<V: View>(
        of view: V,
        named name: String,
        precision: Float = 0.99,
        perceptualPrecision: Float = 0.98,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        guard !isIPad else { return }

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
        guard !isIPad else { return }

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

    // MARK: - iPad Helpers

    /// Snapshot a view in both light and dark mode using a fixed iPad Pro 12.9" viewport.
    func assertLightAndDarkSnapshotIPad<V: View>(
        of view: V,
        named name: String,
        precision: Float = 0.99,
        perceptualPrecision: Float = 0.98,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        guard isIPad else { return }

        let lightView = view
            .environment(\.colorScheme, .light)

        let darkView = view
            .environment(\.colorScheme, .dark)

        assertSnapshot(
            of: UIHostingController(rootView: lightView),
            as: .image(on: .iPadPro12_9(.portrait), precision: precision, perceptualPrecision: perceptualPrecision),
            named: "\(name)-ipad-light",
            file: file,
            testName: testName,
            line: line
        )

        assertSnapshot(
            of: UIHostingController(rootView: darkView),
            as: .image(on: .iPadPro12_9(.portrait), precision: precision, perceptualPrecision: perceptualPrecision),
            named: "\(name)-ipad-dark",
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Snapshot a view at two Dynamic Type sizes on iPad for accessibility testing.
    func assertAccessibilitySnapshotIPad<V: View>(
        of view: V,
        named name: String,
        precision: Float = 0.99,
        perceptualPrecision: Float = 0.98,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        guard isIPad else { return }

        let extraLargeView = view
            .environment(\.dynamicTypeSize, .xxxLarge)

        assertSnapshot(
            of: UIHostingController(rootView: extraLargeView),
            as: .image(on: .iPadPro12_9(.portrait), precision: precision, perceptualPrecision: perceptualPrecision),
            named: "\(name)-ipad-xxxLarge",
            file: file,
            testName: testName,
            line: line
        )

        let accessibilityView = view
            .environment(\.dynamicTypeSize, .accessibility3)

        assertSnapshot(
            of: UIHostingController(rootView: accessibilityView),
            as: .image(on: .iPadPro12_9(.portrait), precision: precision, perceptualPrecision: perceptualPrecision),
            named: "\(name)-ipad-accessibility3",
            file: file,
            testName: testName,
            line: line
        )
    }

    // MARK: - Environment Helpers

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
