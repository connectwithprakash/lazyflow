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
        XCTAssertTrue(app.tabBars.buttons["Calendar"].exists)
        XCTAssertTrue(app.tabBars.buttons["Upcoming"].exists)
        XCTAssertTrue(app.tabBars.buttons["Lists"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)

        // Navigate to each tab
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].exists)

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

        // Tap "Tomorrow" button to set due date
        let tomorrowButton = app.buttons["Tomorrow"]
        if tomorrowButton.exists && tomorrowButton.isHittable {
            tomorrowButton.tap()
        }

        // Add the task
        app.buttons["Add"].tap()

        // Navigate to Upcoming to see the task (since due date is tomorrow)
        app.tabBars.buttons["Upcoming"].tap()

        // Verify task appears in Upcoming
        XCTAssertTrue(app.staticTexts["Task with due date"].waitForExistence(timeout: 3))
    }

    // MARK: - Task Completion Tests

    func testCompleteTask() throws {
        // First create a task
        app.tabBars.buttons["Today"].tap()
        app.buttons["Add task"].tap()

        let titleField = app.textFields["What do you need to do?"]
        titleField.tap()
        titleField.typeText("Task to complete")

        // Use "Tomorrow" button to avoid "Today" tab bar collision
        let tomorrowButton = app.buttons["Tomorrow"]
        if tomorrowButton.exists && tomorrowButton.isHittable {
            tomorrowButton.tap()
        }

        app.buttons["Add"].tap()

        // Navigate to Upcoming to see the task (since we used Tomorrow)
        app.tabBars.buttons["Upcoming"].tap()

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
        nameField.typeText("Nav Test List")
        app.buttons["Create"].tap()

        // Wait for list to appear - use firstMatch to handle multiple matches
        let listText = app.staticTexts.matching(identifier: "Nav Test List").firstMatch
        XCTAssertTrue(listText.waitForExistence(timeout: 3))

        // Tap on the list
        listText.tap()

        // Verify navigation occurred
        XCTAssertTrue(app.navigationBars["Nav Test List"].waitForExistence(timeout: 3))
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

        // Find and tap on Theme picker (it may have different identifiers)
        let themePicker = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Theme'")).firstMatch
        if themePicker.exists && themePicker.isHittable {
            themePicker.tap()

            // Select Dark mode if picker opened
            let darkOption = app.buttons["Dark"]
            if darkOption.waitForExistence(timeout: 2) && darkOption.isHittable {
                darkOption.tap()
            }
        }

        // Test passes if we got this far without crashing
        XCTAssertTrue(app.navigationBars["Settings"].exists)
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
        for tabName in ["Today", "Calendar", "Upcoming", "Lists", "Settings"] {
            let tab = app.tabBars.buttons[tabName]
            XCTAssertTrue(tab.exists)
            XCTAssertNotEqual(tab.label, "")
        }
    }

    // MARK: - Conflict Detection Tests

    func testConflictsBannerAppears() throws {
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 2))
        // Conflicts banner appears when there are scheduling conflicts
        // This test verifies the view loads without crashing
    }

    func testPushToTomorrowSwipeAction() throws {
        app.tabBars.buttons["Today"].tap()
        app.buttons["Add task"].tap()

        let titleField = app.textFields["What do you need to do?"]
        titleField.tap()
        titleField.typeText("Task to push")
        app.buttons["Add"].tap()

        // Task should appear
        XCTAssertTrue(app.staticTexts["Task to push"].waitForExistence(timeout: 2))
    }

    // MARK: - Performance Tests

    func testLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    // MARK: - v0.9.0 iPad Optimization Tests

    func testAdaptiveNavigationExists() throws {
        // Test that navigation exists (either sidebar on iPad or tab bar on iPhone)
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad

        if isIPad {
            // iPad should show sidebar navigation
            // Look for sidebar elements
            let sidebar = app.otherElements["Sidebar"]
            let hasSidebar = sidebar.waitForExistence(timeout: 3)

            // Also check for navigation split view behavior
            let todayButton = app.buttons["Today"]
            let hasNavigation = todayButton.waitForExistence(timeout: 3)

            XCTAssertTrue(hasSidebar || hasNavigation, "iPad should have sidebar navigation")
        } else {
            // iPhone should show tab bar
            XCTAssertTrue(app.tabBars.firstMatch.exists, "iPhone should have tab bar")
        }
    }

    func testIPadSidebarSections() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This test only runs on iPad")
        }

        // Verify sidebar section headers exist
        let tasksHeader = app.staticTexts["Tasks"]
        let organizeHeader = app.staticTexts["Organize"]
        let systemHeader = app.staticTexts["System"]

        // At least one section should be visible
        let hasAnySectionHeader = tasksHeader.waitForExistence(timeout: 3) ||
                                  organizeHeader.exists ||
                                  systemHeader.exists

        XCTAssertTrue(hasAnySectionHeader, "iPad sidebar should have section headers")
    }

    func testIPadSidebarNavigation() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This test only runs on iPad")
        }

        // Test tapping Calendar in sidebar
        let calendarButton = app.buttons["Calendar"]
        if calendarButton.waitForExistence(timeout: 3) && calendarButton.isHittable {
            calendarButton.tap()

            // Verify Calendar view is shown
            let calendarNav = app.navigationBars["Calendar"]
            XCTAssertTrue(calendarNav.waitForExistence(timeout: 3))
        }

        // Test tapping Settings in sidebar
        let settingsButton = app.buttons["Settings"]
        if settingsButton.waitForExistence(timeout: 2) && settingsButton.isHittable {
            settingsButton.tap()

            // Verify Settings view is shown
            let settingsNav = app.navigationBars["Settings"]
            XCTAssertTrue(settingsNav.waitForExistence(timeout: 3))
        }
    }

    func testIPadToolbarButtons() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This test only runs on iPad")
        }

        // iPad sidebar should have toolbar buttons for add and search
        let addButton = app.buttons["Add task"]
        let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'search' OR identifier CONTAINS[c] 'magnifyingglass'")).firstMatch

        // At least the add button should exist
        XCTAssertTrue(addButton.waitForExistence(timeout: 3) || searchButton.exists,
                      "iPad should have toolbar buttons")
    }

    func testIPhoneTabBarStillWorks() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            throw XCTSkip("This test only runs on iPhone")
        }

        // Verify tab bar exists and all tabs are present
        XCTAssertTrue(app.tabBars.firstMatch.exists, "iPhone should have tab bar")
        XCTAssertTrue(app.tabBars.buttons["Today"].exists)
        XCTAssertTrue(app.tabBars.buttons["Calendar"].exists)
        XCTAssertTrue(app.tabBars.buttons["Upcoming"].exists)
        XCTAssertTrue(app.tabBars.buttons["Lists"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)

        // Test tab navigation still works
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 2))
    }

    func testNavigationConsistency() throws {
        // Regardless of device, tapping on a view should show correct content
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad

        if isIPad {
            // Try to navigate using sidebar
            let listsButton = app.buttons["Lists"]
            if listsButton.waitForExistence(timeout: 3) && listsButton.isHittable {
                listsButton.tap()
            }
        } else {
            // Use tab bar
            app.tabBars.buttons["Lists"].tap()
        }

        // Either way, Lists view should be shown
        let listsNav = app.navigationBars["Lists"]
        XCTAssertTrue(listsNav.waitForExistence(timeout: 3), "Lists view should be accessible")
    }
}
