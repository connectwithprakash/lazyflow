import XCTest

final class TaskweaveUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigation Tests

    func testTabBarNavigation() throws {
        // Verify all tabs are present
        XCTAssertTrue(app.tabBars.buttons["Today"].exists)
        XCTAssertTrue(app.tabBars.buttons["Upcoming"].exists)
        XCTAssertTrue(app.tabBars.buttons["Lists"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)

        // Navigate to each tab
        app.tabBars.buttons["Upcoming"].tap()
        XCTAssertTrue(app.navigationBars["Upcoming"].exists)

        app.tabBars.buttons["Lists"].tap()
        XCTAssertTrue(app.navigationBars["Lists"].exists)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)

        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.navigationBars["Today"].exists)
    }

    // MARK: - Task Creation Tests

    func testAddTaskFlow() throws {
        // Navigate to Today view
        app.tabBars.buttons["Today"].tap()

        // Tap add button
        app.buttons["Add task"].tap()

        // Verify add task sheet appears
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 2))

        // Enter task title
        let titleField = app.textFields["What do you need to do?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("Test Task from UI Test")

        // Tap Add button
        app.buttons["Add"].tap()

        // Verify task appears in list
        XCTAssertTrue(app.staticTexts["Test Task from UI Test"].waitForExistence(timeout: 2))
    }

    func testAddTaskWithDueDate() throws {
        app.tabBars.buttons["Today"].tap()
        app.buttons["Add task"].tap()

        let titleField = app.textFields["What do you need to do?"]
        titleField.tap()
        titleField.typeText("Task with due date")

        // Tap Today quick action
        app.buttons["Today"].tap()

        // Add the task
        app.buttons["Add"].tap()

        // Verify task appears
        XCTAssertTrue(app.staticTexts["Task with due date"].waitForExistence(timeout: 2))
    }

    // MARK: - Task Completion Tests

    func testCompleteTask() throws {
        // First create a task
        app.tabBars.buttons["Today"].tap()
        app.buttons["Add task"].tap()

        let titleField = app.textFields["What do you need to do?"]
        titleField.tap()
        titleField.typeText("Task to complete")
        app.buttons["Today"].tap()
        app.buttons["Add"].tap()

        // Wait for task to appear
        let taskText = app.staticTexts["Task to complete"]
        XCTAssertTrue(taskText.waitForExistence(timeout: 2))

        // Find and tap the checkbox
        // The checkbox should be near the task text
        let checkboxButton = app.buttons["Mark complete"].firstMatch
        if checkboxButton.exists {
            checkboxButton.tap()

            // Task should now appear in completed section
            // Or be marked with strikethrough
        }
    }

    // MARK: - List Tests

    func testCreateNewList() throws {
        app.tabBars.buttons["Lists"].tap()

        // Tap add list button
        app.buttons["Add list"].tap()

        // Verify sheet appears
        XCTAssertTrue(app.navigationBars["New List"].waitForExistence(timeout: 2))

        // Enter list name
        let nameField = app.textFields["List Name"]
        nameField.tap()
        nameField.typeText("Work Projects")

        // Tap Create
        app.buttons["Create"].tap()

        // Verify list appears
        XCTAssertTrue(app.staticTexts["Work Projects"].waitForExistence(timeout: 2))
    }

    func testNavigateToList() throws {
        // First create a list
        app.tabBars.buttons["Lists"].tap()
        app.buttons["Add list"].tap()

        let nameField = app.textFields["List Name"]
        nameField.tap()
        nameField.typeText("Test List")
        app.buttons["Create"].tap()

        // Tap on the list to navigate
        app.staticTexts["Test List"].tap()

        // Verify navigation occurred
        XCTAssertTrue(app.navigationBars["Test List"].waitForExistence(timeout: 2))
    }

    // MARK: - Settings Tests

    func testSettingsAppearance() throws {
        app.tabBars.buttons["Settings"].tap()

        // Verify settings sections exist
        XCTAssertTrue(app.staticTexts["Appearance"].exists)
        XCTAssertTrue(app.staticTexts["Tasks"].exists)
        XCTAssertTrue(app.staticTexts["Notifications"].exists)
    }

    func testChangeTheme() throws {
        app.tabBars.buttons["Settings"].tap()

        // Tap on Theme picker
        app.buttons["Theme, System"].tap()

        // Select Dark mode
        app.buttons["Dark"].tap()

        // Verify selection
        XCTAssertTrue(app.buttons["Theme, Dark"].exists)
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() throws {
        // Verify important elements have accessibility labels
        app.tabBars.buttons["Today"].tap()

        let addButton = app.buttons["Add task"]
        XCTAssertTrue(addButton.exists)
        XCTAssertTrue(addButton.isHittable)
    }

    func testVoiceOverSupport() throws {
        // This test verifies that key elements are accessible to VoiceOver
        app.tabBars.buttons["Today"].tap()

        // All tab bar items should be accessible
        for tabName in ["Today", "Upcoming", "Lists", "Settings"] {
            let tab = app.tabBars.buttons[tabName]
            XCTAssertTrue(tab.exists)
            XCTAssertNotEqual(tab.label, "")
        }
    }

    // MARK: - Performance Tests

    func testLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
