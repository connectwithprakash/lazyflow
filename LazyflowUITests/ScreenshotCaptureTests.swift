import XCTest

/// Captures design-gallery screenshots of the Knowledge Graph UI (#152).
///
/// Not part of the functional suite — skipped unless explicitly enabled.
/// Run on demand per appearance:
/// ```
/// xcrun simctl ui booted appearance light   # or dark
/// TEST_RUNNER_CAPTURE_SCREENSHOTS=1 xcodebuild test ... \
///   -only-testing:LazyflowUITests/ScreenshotCaptureTests
/// ```
/// Attachments are exported from the result bundle via
/// `xcresulttool export attachments` into docs/site/assets/screenshots/.
final class ScreenshotCaptureTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CAPTURE_SCREENSHOTS"] == "1",
            "On-demand capture utility — set CAPTURE_SCREENSHOTS=1 to run"
        )
        continueAfterFailure = false
        // Gallery screenshots are portrait; the simulator may be left rotated
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launchEnvironment = ["UI_TESTING": "1"]
        app.launch()
    }

    func testCaptureKnowledgeGraphScreens() throws {
        // Me tab → AI settings
        let meTab = app.tabBars.buttons["Me"]
        XCTAssertTrue(meTab.waitForExistence(timeout: 5))
        meTab.tap()
        tapHubItem("AI")
        XCTAssertTrue(app.navigationBars["AI Settings"].waitForExistence(timeout: 3))

        // Bring the Experimental / Knowledge Graph section into view
        let kgLabel = app.staticTexts["Knowledge Graph"]
        for _ in 0..<3 where !(kgLabel.exists && kgLabel.isHittable) {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }
        Thread.sleep(forTimeInterval: 0.5)
        attach("knowledge-graph-settings")

        // Back to Me → Data & About danger zone
        app.navigationBars.buttons.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.5)
        tapHubItem("Data & About")
        XCTAssertTrue(app.navigationBars["Data & About"].waitForExistence(timeout: 3))

        let resetLabel = app.staticTexts["Reset Knowledge Graph"]
        for _ in 0..<4 where !(resetLabel.exists && resetLabel.isHittable) {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }
        Thread.sleep(forTimeInterval: 0.5)
        attach("knowledge-graph-reset")
    }

    /// Landscape audit for #297: rotate, walk the main surfaces, attach a
    /// screenshot of each. Not a pass/fail test — a survey tool.
    func testAuditLandscapeScreens() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.0)

        // Diagnostic: does the window actually adopt landscape dimensions?
        let window = app.windows.firstMatch
        print("AUDIT device orientation: \(XCUIDevice.shared.orientation.rawValue)")
        print("AUDIT window frame: \(window.frame)")
        print("AUDIT app frame: \(app.frame)")

        // Tabs
        for tab in ["Today", "Calendar", "Upcoming", "Insights", "Me"] {
            let button = app.tabBars.buttons[tab]
            if button.waitForExistence(timeout: 3) {
                button.tap()
                Thread.sleep(forTimeInterval: 0.8)
                attach("landscape-\(tab.lowercased())")
            }
        }

        // Add Task sheet
        app.tabBars.buttons["Today"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        let addButton = app.buttons["Add task"]
        if addButton.waitForExistence(timeout: 3) && addButton.isHittable {
            addButton.tap()
            Thread.sleep(forTimeInterval: 0.8)
            attach("landscape-add-task")
            let cancel = app.buttons["Cancel"]
            if cancel.exists && cancel.isHittable { cancel.tap() }
        }

        // Settings leaf page (representative Form)
        app.tabBars.buttons["Me"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        tapHubItem("AI")
        Thread.sleep(forTimeInterval: 0.8)
        attach("landscape-ai-settings")

        XCUIDevice.shared.orientation = .portrait
    }

    /// Control experiment (#297): does Safari rotate under the same harness?
    /// Distinguishes "Lazyflow refuses rotation" from "simulator/harness
    /// rotation is broken".
    func testAuditControlSafariRotation() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()
        _ = safari.wait(for: .runningForeground, timeout: 10)

        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.5)
        print("AUDIT safari window frame: \(safari.windows.firstMatch.frame)")

        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1.0)
        safari.terminate()
    }

    // MARK: - Helpers

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapHubItem(_ itemName: String) {
        let cardText = app.staticTexts[itemName]
        for _ in 0..<3 {
            if cardText.waitForExistence(timeout: 3) && cardText.isHittable {
                cardText.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.5)
                return
            }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }
        if cardText.exists { cardText.tap() }
    }
}
