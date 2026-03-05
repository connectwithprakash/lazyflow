import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow
import LazyflowCore

final class QuickCaptureSheetSnapshotTests: SnapshotTestCase {

    func testNewNoteMode() {
        let view = QuickCaptureSheet()
        assertLightAndDarkSnapshot(of: view, named: "newNote")
    }

    func testEditNoteMode() {
        let note = SnapshotFixtures.sampleNote()
        let view = QuickCaptureSheet(note: note, onExtract: { _ in })
        assertLightAndDarkSnapshot(of: view, named: "editNote")
    }
}
