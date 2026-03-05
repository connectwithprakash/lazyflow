import XCTest
import SwiftUI
import SnapshotTesting
import LazyflowCore
@testable import Lazyflow

final class QuickCaptureReviewViewSnapshotTests: SnapshotTestCase {

    func testExtractingState() {
        let vm = QuickCaptureViewModel(note: SnapshotFixtures.sampleNote())
        // Default state is .extracting — no need to change
        let view = QuickCaptureReviewView(viewModel: vm)
        assertLightAndDarkSnapshot(of: view, named: "extracting")
    }

    func testReviewState() {
        let vm = QuickCaptureViewModel(note: SnapshotFixtures.sampleNote())
        vm.viewState = .review
        vm.drafts = SnapshotFixtures.sampleDrafts()
        let view = QuickCaptureReviewView(viewModel: vm)
        assertLightAndDarkSnapshot(of: view, named: "review")
    }

    func testCompletedState() {
        let vm = QuickCaptureViewModel(note: SnapshotFixtures.sampleNote())
        vm.viewState = .completed(count: 3)
        let view = QuickCaptureReviewView(viewModel: vm)
        assertLightAndDarkSnapshot(of: view, named: "completed")
    }

    func testErrorState() {
        let vm = QuickCaptureViewModel(note: SnapshotFixtures.sampleNote())
        vm.viewState = .error(message: "Could not connect to AI service. Please check your settings and try again.")
        let view = QuickCaptureReviewView(viewModel: vm)
        assertLightAndDarkSnapshot(of: view, named: "error")
    }
}
