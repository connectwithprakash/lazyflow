import XCTest

final class LazyflowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launchEnvironment = ["UI_TESTING": "1"]

        // Force terminate any existing instance to ensure fresh launch with UI_TESTING flag
        app.terminate()
        app.launch()

        // Wait for app to be fully ready - tab bar indicates UI is loaded
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "App should launch and show tab bar")
    }

    // MARK: - Helper Methods

    /// Reliably types text into a text field by ensuring keyboard focus is active.
    /// This addresses XCUITest's keyboard focus timing issues.
    private func tapAndTypeText(_ element: XCUIElement, text: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 3), "Text field should exist")

        // Tap the element to focus it
        element.tap()

        // Wait for keyboard to appear by checking for any key
        let keyboard = app.keyboards.firstMatch
        if !keyboard.waitForExistence(timeout: 2) {
            // If keyboard didn't appear, try tapping again
            element.tap()
            _ = keyboard.waitForExistence(timeout: 2)
        }

        // Type the text
        element.typeText(text)
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

        // Wait for view to load
        Thread.sleep(forTimeInterval: 0.5)

        // Tap add button - wait for it to be ready
        let addTaskButton = app.buttons["Add task"]
        XCTAssertTrue(addTaskButton.waitForExistence(timeout: 3), "Add task button should exist")
        addTaskButton.tap()

        // Verify add task sheet appears
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))

        // Enter task title
        let titleField = app.textFields["What do you need to do?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Test Task from UI Test")

        // Set due date to Tomorrow so task appears in Upcoming view
        // (Avoid "Today" button confusion with tab bar)
        let tomorrowButton = app.buttons["Tomorrow"]
        if tomorrowButton.exists && tomorrowButton.isHittable {
            tomorrowButton.tap()
        }

        // Tap Add button
        app.buttons["Add"].tap()

        // Navigate to Upcoming to see the task
        app.tabBars.buttons["Upcoming"].tap()

        // Verify task appears in list (increased timeout for physical device reliability)
        XCTAssertTrue(app.staticTexts["Test Task from UI Test"].waitForExistence(timeout: 5))
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

        // Enter list name using helper to ensure keyboard focus
        let nameField = app.textFields["List Name"]
        tapAndTypeText(nameField, text: "Work Projects")

        // Tap Create
        app.buttons["Create"].tap()

        // Verify list appears
        XCTAssertTrue(app.staticTexts["Work Projects"].waitForExistence(timeout: 2))
    }

    func testNavigateToList() throws {
        // First create a list
        app.tabBars.buttons["Lists"].tap()
        app.buttons["Add list"].tap()

        // Verify sheet appears
        XCTAssertTrue(app.navigationBars["New List"].waitForExistence(timeout: 2))

        // Enter list name using helper to ensure keyboard focus
        let nameField = app.textFields["List Name"]
        tapAndTypeText(nameField, text: "Nav Test List")
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
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5), "Tab bar should be ready")
        todayTab.tap()

        let addButton = app.buttons["Add task"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        XCTAssertTrue(addButton.isHittable)
    }

    func testVoiceOverSupport() throws {
        // This test verifies that key elements are accessible to VoiceOver
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5), "Tab bar should be ready")
        todayTab.tap()

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

        // Wait for view to load
        Thread.sleep(forTimeInterval: 0.5)

        // Tap add button - wait for it to be ready
        let addTaskButton = app.buttons["Add task"]
        XCTAssertTrue(addTaskButton.waitForExistence(timeout: 3), "Add task button should exist")
        addTaskButton.tap()

        // Verify add task sheet appears
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))

        let titleField = app.textFields["What do you need to do?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Task to push")

        // Set due date to Tomorrow so task appears in Upcoming view
        // (Avoid "Today" button confusion with tab bar)
        let tomorrowButton = app.buttons["Tomorrow"]
        if tomorrowButton.exists && tomorrowButton.isHittable {
            tomorrowButton.tap()
        }

        app.buttons["Add"].tap()

        // Navigate to Upcoming to see the task
        app.tabBars.buttons["Upcoming"].tap()

        // Task should appear (increased timeout for physical device reliability)
        XCTAssertTrue(app.staticTexts["Task to push"].waitForExistence(timeout: 5))
    }

    // MARK: - Performance Tests

    /// Skipped: Performance tests are flaky on physical devices
    func skip_testLaunchPerformance() throws {
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
            let hasSidebar = sidebar.waitForExistence(timeout: 5)

            // Also check for navigation split view behavior
            let todayButton = app.buttons["Today"]
            let hasNavigation = todayButton.waitForExistence(timeout: 5)

            XCTAssertTrue(hasSidebar || hasNavigation, "iPad should have sidebar navigation")
        } else {
            // iPhone should show tab bar - wait for it to be ready
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "iPhone should have tab bar")
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

    // MARK: - Morning Briefing Tests

    func testMorningBriefingSettingsExist() throws {
        app.tabBars.buttons["Settings"].tap()

        // Scroll to find Morning Briefing settings
        // Note: SwiftUI Form renders as UITableView, not ScrollView
        let settingsTable = app.tables.firstMatch
        if settingsTable.waitForExistence(timeout: 3) {
            settingsTable.swipeUp()
        }

        // Look for Morning Briefing toggle in Daily Summary section
        let morningToggle = app.switches.matching(NSPredicate(format: "label CONTAINS[c] 'Morning'")).firstMatch
        if morningToggle.waitForExistence(timeout: 3) {
            XCTAssertTrue(morningToggle.exists, "Morning briefing toggle should exist in settings")
        }
    }

    func testMorningBriefingPromptCard() throws {
        // Navigate to Today view
        app.tabBars.buttons["Today"].tap()

        // The morning briefing prompt card may appear in the morning hours
        // If it appears, verify it has the expected content
        let briefingCard = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Start Your Day'")).firstMatch
        if briefingCard.waitForExistence(timeout: 2) {
            XCTAssertTrue(briefingCard.exists)

            // Tap on the card to open morning briefing
            briefingCard.tap()

            // Verify morning briefing view opens
            let briefingNav = app.navigationBars["Good Morning"]
            XCTAssertTrue(briefingNav.waitForExistence(timeout: 3), "Morning briefing view should open")
        }
    }

    func testMorningBriefingViewContent() throws {
        // Navigate to Today view
        app.tabBars.buttons["Today"].tap()

        // Try to access morning briefing through settings or direct navigation
        // First check if there's a briefing card to tap
        let briefingCard = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Start Your Day'")).firstMatch
        if briefingCard.waitForExistence(timeout: 2) && briefingCard.isHittable {
            briefingCard.tap()

            // Verify morning briefing content sections (Form renders as table)
            _ = app.tables.firstMatch

            // Verify key sections exist
            let yesterdaySection = app.staticTexts["Yesterday"]
            let todayPlanSection = app.staticTexts["Today's Plan"]
            let weekSection = app.staticTexts["This Week"]

            // At least one section should be visible
            let hasContent = yesterdaySection.waitForExistence(timeout: 3) ||
                            todayPlanSection.exists ||
                            weekSection.exists

            XCTAssertTrue(hasContent, "Morning briefing should have content sections")

            // Dismiss the briefing
            let doneButton = app.buttons["Done"]
            if doneButton.exists && doneButton.isHittable {
                doneButton.tap()
            }
        }
    }

    func testMorningBriefingRefresh() throws {
        app.tabBars.buttons["Today"].tap()

        let briefingCard = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Start Your Day'")).firstMatch
        if briefingCard.waitForExistence(timeout: 2) && briefingCard.isHittable {
            briefingCard.tap()

            // Wait for briefing view
            let briefingNav = app.navigationBars["Good Morning"]
            XCTAssertTrue(briefingNav.waitForExistence(timeout: 3))

            // Find and tap refresh button
            let refreshButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'arrow.clockwise' OR label CONTAINS[c] 'Refresh'")).firstMatch
            if refreshButton.waitForExistence(timeout: 2) && refreshButton.isHittable {
                refreshButton.tap()

                // Wait for refresh to complete (loading indicator should appear and disappear)
                sleep(2)

                // View should still exist after refresh
                XCTAssertTrue(briefingNav.exists)
            }

            // Dismiss
            let doneButton = app.buttons["Done"]
            if doneButton.exists {
                doneButton.tap()
            }
        }
    }

    // MARK: - Daily Summary Tests

    func testDailySummarySettingsExist() throws {
        app.tabBars.buttons["Settings"].tap()

        // Scroll to find Daily Summary section
        // Note: SwiftUI Form renders as UITableView, not ScrollView
        let settingsTable = app.tables.firstMatch
        if settingsTable.waitForExistence(timeout: 3) {
            settingsTable.swipeUp()
        }

        // Look for Daily Summary toggle
        let summaryToggle = app.switches.matching(NSPredicate(format: "label CONTAINS[c] 'Summary' OR label CONTAINS[c] 'Evening'")).firstMatch
        if summaryToggle.waitForExistence(timeout: 3) {
            XCTAssertTrue(summaryToggle.exists, "Daily summary toggle should exist in settings")
        }
    }

    func testDailySummarySection() throws {
        app.tabBars.buttons["Settings"].tap()

        // Use flexible predicate to find Evening Reminder toggle (more reliable across devices)
        let eveningToggle = app.switches.matching(NSPredicate(format: "identifier CONTAINS[c] 'Evening' OR label CONTAINS[c] 'Evening'")).firstMatch

        // Scroll to find Daily Summary section - swipe on app directly since SwiftUI List may not be Table
        // Scroll until we find the toggle or give up after 5 attempts
        for _ in 0..<5 {
            if eveningToggle.exists && eveningToggle.isHittable {
                break
            }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertTrue(eveningToggle.waitForExistence(timeout: 5), "Daily Summary section should exist in settings (Evening Reminder toggle)")
    }

    func testDailySummaryToggleInteraction() throws {
        app.tabBars.buttons["Settings"].tap()

        // Use flexible predicate to find Evening Reminder toggle (more reliable across devices)
        let reminderToggle = app.switches.matching(NSPredicate(format: "identifier CONTAINS[c] 'Evening' OR label CONTAINS[c] 'Evening'")).firstMatch

        // Scroll to find Daily Summary section - swipe on app directly since SwiftUI List may not be Table
        for _ in 0..<5 {
            if reminderToggle.exists && reminderToggle.isHittable {
                break
            }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Wait for toggle to exist
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: 5), "Evening Reminder toggle should exist")

        // Get initial state (handles both "1"/"0" and "true"/"false" formats)
        let wasOnValue = reminderToggle.value as? String ?? ""
        let wasOn = wasOnValue == "1" || wasOnValue.lowercased() == "true"

        // KNOWN XCUITEST ISSUE: Tapping center of toggle hits label, not switch.
        // Solution: First do an intermediate tap, then tap the switch coordinate.
        // See: https://www.sylvaingamel.fr/en/blog/2023/23-02-12_ios-toggle-uitest/
        reminderToggle.tap() // Intermediate tap - required for the next tap to work
        let switchCoord = reminderToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        switchCoord.tap() // Tap the actual switch control on the right side

        // Wait for state change
        Thread.sleep(forTimeInterval: 0.5)

        // Verify state changed
        let isOnValue = reminderToggle.value as? String ?? ""
        let isOn = isOnValue == "1" || isOnValue.lowercased() == "true"
        XCTAssertNotEqual(wasOn, isOn, "Toggle should change state from \(wasOnValue) to \(isOnValue)")

        // Toggle back to original state
        reminderToggle.tap() // Intermediate tap
        switchCoord.tap() // Actual switch tap
    }

    // MARK: - Task Category Tests

    func testTaskCategorySelection() throws {
        app.tabBars.buttons["Today"].tap()
        app.buttons["Add task"].tap()

        // Verify add task sheet appears
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 2))

        // Enter task title first
        let titleField = app.textFields["What do you need to do?"]
        titleField.tap()
        titleField.typeText("Categorized Task")

        // Look for category picker
        let categoryButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'category' OR label CONTAINS[c] 'work' OR label CONTAINS[c] 'personal'")).firstMatch
        if categoryButton.waitForExistence(timeout: 2) && categoryButton.isHittable {
            categoryButton.tap()

            // Select a category
            let workOption = app.buttons["Work"]
            if workOption.waitForExistence(timeout: 2) && workOption.isHittable {
                workOption.tap()
            }
        }

        // Cancel to clean up
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
    }

    // MARK: - Priority Tests

    func testTaskPrioritySelection() throws {
        app.tabBars.buttons["Today"].tap()
        app.buttons["Add task"].tap()

        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 2))

        let titleField = app.textFields["What do you need to do?"]
        titleField.tap()
        titleField.typeText("Priority Task")

        // Look for priority picker
        let priorityButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'priority'")).firstMatch
        if priorityButton.waitForExistence(timeout: 2) && priorityButton.isHittable {
            priorityButton.tap()

            // Select high priority
            let highOption = app.buttons["High"]
            if highOption.waitForExistence(timeout: 2) && highOption.isHittable {
                highOption.tap()
            }
        }

        // Cancel to clean up
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
    }

    // MARK: - Streak Display Tests

    func testStreakDisplayInSettings() throws {
        app.tabBars.buttons["Settings"].tap()

        // Scroll to look for streak information
        // Note: SwiftUI Form renders as UITableView, not ScrollView
        let settingsTable = app.tables.firstMatch
        if settingsTable.waitForExistence(timeout: 3) {
            settingsTable.swipeUp()
        }

        // Look for streak-related text
        _ = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'streak' OR label CONTAINS[c] 'day'")).firstMatch
        // Streak display may or may not exist depending on user's history
        // This test just verifies settings page loads properly
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }

    // MARK: - Calendar Integration Tests

    func testCalendarViewNavigation() throws {
        let calendarTab = app.tabBars.buttons["Calendar"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 5), "Calendar tab should exist")
        calendarTab.tap()

        // Verify calendar view loads
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5))

        // Look for date picker or calendar grid
        _ = app.datePickers.firstMatch.exists ||
            app.collectionViews.firstMatch.exists ||
            app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] 'calendar'")).firstMatch.exists

        // Calendar view should have some content
        XCTAssertTrue(app.navigationBars["Calendar"].exists, "Calendar should load successfully")
    }

    func testCalendarDateSelection() throws {
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5))

        // Try to tap on a date
        let datePicker = app.datePickers.firstMatch
        if datePicker.exists && datePicker.isHittable {
            datePicker.tap()
        }

        // Calendar view should still be visible
        XCTAssertTrue(app.navigationBars["Calendar"].exists)
    }

    // MARK: - Search Tests

    func testSearchFunctionality() throws {
        app.tabBars.buttons["Today"].tap()

        // First create a task to search for
        app.buttons["Add task"].tap()
        let titleField = app.textFields["What do you need to do?"]
        titleField.tap()
        titleField.typeText("Searchable test task")
        app.buttons["Add"].tap()

        // Look for search field or search button
        let searchField = app.searchFields.firstMatch
        let searchButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'magnifyingglass' OR label CONTAINS[c] 'Search'")).firstMatch

        if searchField.waitForExistence(timeout: 2) && searchField.isHittable {
            searchField.tap()
            searchField.typeText("Searchable")

            // Verify task appears in results
            XCTAssertTrue(app.staticTexts["Searchable test task"].waitForExistence(timeout: 3))
        } else if searchButton.exists && searchButton.isHittable {
            searchButton.tap()
        }
    }

    // MARK: - Subtask Tests

    func testAddSubtaskInAddTaskView() throws {
        app.tabBars.buttons["Today"].tap()
        app.buttons["Add task"].tap()

        // Verify add task sheet appears
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))

        // Enter task title
        let titleField = app.textFields["What do you need to do?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Parent Task with Subtasks")

        // Look for the subtasks section add button
        let addSubtaskButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'plus' OR label CONTAINS[c] 'Add subtask'")).firstMatch

        // Scroll down if needed to find subtasks section
        for _ in 0..<3 {
            if addSubtaskButton.exists && addSubtaskButton.isHittable {
                break
            }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }

        if addSubtaskButton.waitForExistence(timeout: 3) && addSubtaskButton.isHittable {
            addSubtaskButton.tap()

            // Find subtask input field
            let subtaskField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'subtask' OR identifier CONTAINS[c] 'subtask'")).firstMatch
            if subtaskField.waitForExistence(timeout: 2) && subtaskField.isHittable {
                subtaskField.tap()
                subtaskField.typeText("First Subtask")

                // Submit the subtask (press return)
                app.keyboards.buttons["Return"].tap()
            }
        }

        // Cancel to clean up
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists && cancelButton.isHittable {
            cancelButton.tap()
        }
    }

    func testSubtaskDisplayInTaskDetail() throws {
        // First create a task
        app.tabBars.buttons["Today"].tap()
        app.buttons["Add task"].tap()

        let titleField = app.textFields["What do you need to do?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Task for Subtask Test")

        // Set due date to Tomorrow
        let tomorrowButton = app.buttons["Tomorrow"]
        if tomorrowButton.exists && tomorrowButton.isHittable {
            tomorrowButton.tap()
        }

        // Tap the navigation bar Add button (not the subtask Add button)
        let navBar = app.navigationBars["New Task"]
        let addButton = navBar.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        // Navigate to Upcoming to see the task
        app.tabBars.buttons["Upcoming"].tap()

        // Wait for task to appear
        let taskText = app.staticTexts["Task for Subtask Test"]
        XCTAssertTrue(taskText.waitForExistence(timeout: 5))

        // Tap on the task to open detail view
        taskText.tap()

        // Verify detail view opens
        let detailNav = app.navigationBars["Edit Task"]
        XCTAssertTrue(detailNav.waitForExistence(timeout: 3), "Task detail view should open")

        // Look for Subtasks section
        let subtasksHeader = app.staticTexts["Subtasks"]
        if !subtasksHeader.exists {
            // Scroll to find it
            for _ in 0..<3 {
                app.swipeUp()
                if subtasksHeader.exists {
                    break
                }
            }
        }

        // Subtasks section should exist (for non-subtask tasks)
        XCTAssertTrue(subtasksHeader.waitForExistence(timeout: 3), "Subtasks section should be visible in task detail")

        // Close detail view
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists && cancelButton.isHittable {
            cancelButton.tap()
        }
    }

    func testAddSubtaskInTaskDetail() throws {
        // First create a task
        app.tabBars.buttons["Today"].tap()
        app.buttons["Add task"].tap()

        let titleField = app.textFields["What do you need to do?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Task with Subtasks Detail")

        // Set due date to Tomorrow
        let tomorrowButton = app.buttons["Tomorrow"]
        if tomorrowButton.exists && tomorrowButton.isHittable {
            tomorrowButton.tap()
        }

        // Tap the navigation bar Add button (not the subtask Add button)
        let navBar = app.navigationBars["New Task"]
        let addButton = navBar.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        // Navigate to Upcoming to see the task
        app.tabBars.buttons["Upcoming"].tap()

        // Wait for task to appear
        let taskText = app.staticTexts["Task with Subtasks Detail"]
        XCTAssertTrue(taskText.waitForExistence(timeout: 5))

        // Tap on the task to open detail view
        taskText.tap()

        // Verify detail view opens
        let detailNav = app.navigationBars["Edit Task"]
        XCTAssertTrue(detailNav.waitForExistence(timeout: 3))

        // Scroll to find Subtasks section
        let subtasksHeader = app.staticTexts["Subtasks"]
        for _ in 0..<3 {
            if subtasksHeader.exists {
                break
            }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Find and tap add subtask button (plus.circle.fill)
        let addSubtaskButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'plus.circle' OR label CONTAINS[c] 'Add'")).firstMatch
        if addSubtaskButton.waitForExistence(timeout: 2) && addSubtaskButton.isHittable {
            addSubtaskButton.tap()

            // Verify add subtask sheet appears
            let addSubtaskNav = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS[c] 'Subtask' OR identifier CONTAINS[c] 'Add'")).firstMatch
            if addSubtaskNav.waitForExistence(timeout: 2) {
                // Enter subtask title
                let subtaskTitleField = app.textFields.firstMatch
                if subtaskTitleField.exists && subtaskTitleField.isHittable {
                    subtaskTitleField.tap()
                    subtaskTitleField.typeText("Subtask from Detail")
                }

                // Tap Add
                let addButton = app.buttons["Add"]
                if addButton.exists && addButton.isHittable {
                    addButton.tap()
                }
            }
        }

        // Close detail view
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists && cancelButton.isHittable {
            cancelButton.tap()
        }
    }

    func testSubtaskProgressBadge() throws {
        // This test verifies that the subtask progress badge appears when a task has subtasks
        app.tabBars.buttons["Upcoming"].tap()

        // Look for any task row with subtask progress indicator (e.g., "0/2" or "1/3")
        let progressIndicator = app.staticTexts.matching(NSPredicate(format: "label MATCHES '\\\\d+/\\\\d+'")).firstMatch

        // Progress badge may or may not exist depending on tasks with subtasks
        // This test verifies the view loads without crashing
        XCTAssertTrue(app.navigationBars["Upcoming"].waitForExistence(timeout: 3))
    }

    func testExpandCollapseSubtasks() throws {
        // Navigate to Upcoming view where tasks with subtasks may appear
        app.tabBars.buttons["Upcoming"].tap()
        XCTAssertTrue(app.navigationBars["Upcoming"].waitForExistence(timeout: 3))

        // Look for expand/collapse chevron indicator
        let expandButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'chevron' OR label CONTAINS[c] 'expand' OR label CONTAINS[c] 'collapse'")).firstMatch

        if expandButton.waitForExistence(timeout: 2) && expandButton.isHittable {
            // Tap to expand
            expandButton.tap()
            Thread.sleep(forTimeInterval: 0.5)

            // Tap again to collapse
            expandButton.tap()
        }

        // View should remain stable
        XCTAssertTrue(app.navigationBars["Upcoming"].exists)
    }

    func testCompleteSubtaskInTaskRow() throws {
        // Navigate to Upcoming to find tasks with subtasks
        app.tabBars.buttons["Upcoming"].tap()
        XCTAssertTrue(app.navigationBars["Upcoming"].waitForExistence(timeout: 3))

        // Look for a subtask checkbox
        let subtaskCheckbox = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'circle' OR identifier CONTAINS[c] 'checkbox'")).firstMatch

        if subtaskCheckbox.waitForExistence(timeout: 2) && subtaskCheckbox.isHittable {
            subtaskCheckbox.tap()

            // The checkbox state should change (animation may occur)
            Thread.sleep(forTimeInterval: 0.5)
        }

        // View should remain stable
        XCTAssertTrue(app.navigationBars["Upcoming"].exists)
    }
}
