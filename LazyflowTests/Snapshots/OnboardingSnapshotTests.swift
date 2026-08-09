import SwiftUI
import XCTest
@testable import Lazyflow

/// Snapshot coverage for OnboardingView in portrait and landscape (#297).
/// The permissions page is the tallest composition and previously clipped
/// in compact height.
@MainActor
final class OnboardingSnapshotTests: SnapshotTestCase {

    func testFirstPage() {
        assertLightAndDarkSnapshot(of: OnboardingView(), named: "onboarding")
    }

    func testFirstPageLandscape() {
        assertLandscapeSnapshot(of: OnboardingView(), named: "onboarding")
    }
}
