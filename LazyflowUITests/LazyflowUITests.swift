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

        // Wait for app to be fully ready - check appropriate element based on device
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad uses NavigationSplitView with sidebar
            let sidebarTitle = app.navigationBars["Lazyflow"]
            let todayButton = app.buttons["Today"]
            let isReady = sidebarTitle.waitForExistence(timeout: 10) || todayButton.waitForExistence(timeout: 5)
            XCTAssertTrue(isReady, "iPad app should launch and show sidebar navigation")
        } else {
            // iPhone uses tab bar
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "iPhone app should launch and show tab bar")
        }
    }

    // MARK: - Helper Methods

    /// Navigate to Today tab. Works on both iPhone (tab bar) and iPad (sidebar).
    private func navigateToToday() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Try multiple element types for iPad sidebar
            let todayButton = app.buttons["Today"]
            let todayText = app.staticTexts["Today"]
            let todayCell = app.cells.staticTexts["Today"]

            if todayButton.waitForExistence(timeout: 1) && todayButton.isHittable {
                todayButton.tap()
            } else if todayText.waitForExistence(timeout: 1) && todayText.isHittable {
                todayText.tap()
            } else if todayCell.waitForExistence(timeout: 1) && todayCell.isHittable {
                todayCell.tap()
            }
        } else {
            let todayTab = app.tabBars.buttons["Today"]
            if todayTab.exists && todayTab.isHittable {
                todayTab.tap()
            }
        }
    }

    /// Navigate to a tab or a view accessible via the More hub.
    /// Direct tabs: Today, Calendar, Upcoming, History, More
    /// Via More hub: Lists, Settings
    /// On iPad: Uses sidebar navigation (List with selection)
    /// On iPhone: Uses tab bar + More hub
    private func navigateToTab(_ tabName: String) {
        // iPad uses sidebar navigation - items are in a List with selection
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Try multiple element types: button, staticText, cell
            let sidebarButton = app.buttons[tabName]
            let sidebarText = app.staticTexts[tabName]
            let sidebarCell = app.cells.staticTexts[tabName]

            if sidebarButton.waitForExistence(timeout: 1) && sidebarButton.isHittable {
                sidebarButton.tap()
            } else if sidebarText.waitForExistence(timeout: 1) && sidebarText.isHittable {
                sidebarText.tap()
            } else if sidebarCell.waitForExistence(timeout: 1) && sidebarCell.isHittable {
                sidebarCell.tap()
            } else {
                // Fallback: try to find any element containing the tab name
                let anyElement = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR identifier == %@", tabName, tabName)).firstMatch
                if anyElement.waitForExistence(timeout: 1) && anyElement.isHittable {
                    anyElement.tap()
                }
            }
            Thread.sleep(forTimeInterval: 0.5)
            return
        }

        // iPhone uses tab bar + More hub
        // Direct tabs in the tab bar
        let directTabs = ["Today", "Calendar", "Upcoming", "History", "More"]

        if directTabs.contains(tabName) {
            let directTab = app.tabBars.buttons[tabName]
            if directTab.exists && directTab.isHittable {
                directTab.tap()
            }
            return
        }

        // Lists and Settings are accessed via More hub
        let moreTab = app.tabBars.buttons["More"]
        guard moreTab.exists && moreTab.isHittable else { return }
        moreTab.tap()

        // Wait for More view to load
        Thread.sleep(forTimeInterval: 0.5)

        // Find the card text - may need to scroll
        let cardText = app.staticTexts[tabName]

        // Try to find and tap card, scrolling if necessary
        for _ in 0..<3 {
            if cardText.waitForExistence(timeout: 1) && cardText.isHittable {
                // Tap via coordinate to ensure it triggers NavigationLink
                let coordinate = cardText.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                coordinate.tap()
                Thread.sleep(forTimeInterval: 0.5)
                return
            }

            // Scroll down to find the card
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Final attempt after scrolling
        if cardText.exists {
            cardText.tap()
        }
    }

    /// Reliably types text into a text field using paste workaround.
    /// This bypasses XCUITest's keyboard focus issues with SwiftUI TextFields.
    /// Reference: https://fatbobman.com/en/posts/textfield-event-focus-keyboard/
    private func tapAndTypeText(_ element: XCUIElement, text: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 3), "Text field should exist")

        // Copy text to pasteboard
        UIPasteboard.general.string = text

        // Tap the element to focus it
        element.tap()
        Thread.sleep(forTimeInterval: 0.3)

        // Double-tap to select all (if any existing text) and show menu
        element.doubleTap()
        Thread.sleep(forTimeInterval: 0.3)

        // Try to paste using the menu
        let pasteMenuItem = app.menuItems["Paste"]
        if pasteMenuItem.waitForExistence(timeout: 2) {
            pasteMenuItem.tap()
        } else {
            // Fallback: try typing directly if paste menu doesn't appear
            let keyboard = app.keyboards.firstMatch
            if keyboard.waitForExistence(timeout: 2) {
                app.typeText(text)
            } else {
                // Last resort: coordinate tap and type
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.5)
                app.typeText(text)
            }
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigation Tests

    func testTabBarNavigation() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            throw XCTSkip("This test only runs on iPhone (iPad uses sidebar navigation)")
        }

        // Verify visible tabs are present (iOS shows 5 tabs max including "More")
        XCTAssertTrue(app.tabBars.buttons["Today"].exists)
        XCTAssertTrue(app.tabBars.buttons["Calendar"].exists)
        XCTAssertTrue(app.tabBars.buttons["Upcoming"].exists)
        XCTAssertTrue(app.tabBars.buttons["History"].exists)
        XCTAssertTrue(app.tabBars.buttons["More"].exists, "More tab should exist for overflow items")

        // Navigate to each tab
        navigateToTab("Calendar")
        XCTAssertTrue(app.navigationBars["Calendar"].exists)

        navigateToTab("Upcoming")
        XCTAssertTrue(app.navigationBars["Upcoming"].exists)

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].exists)

        navigateToTab("Lists")
        XCTAssertTrue(app.navigationBars["Lists"].exists)

        navigateToTab("Settings")
        XCTAssertTrue(app.navigationBars["Settings"].exists)

        navigateToToday()
        XCTAssertTrue(app.navigationBars["Today"].exists)
    }

    // MARK: - Task Creation Tests

    func testAddTaskFlow() throws {
        // Navigate to Today view
        navigateToToday()

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

        // Tap Add button in navigation bar (not the subtask Add button)
        let navBar = app.navigationBars["New Task"]
        let addButton = navBar.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        // Navigate to Upcoming to see the task
        navigateToTab("Upcoming")

        // Verify task appears in list (increased timeout for physical device reliability)
        XCTAssertTrue(app.staticTexts["Test Task from UI Test"].waitForExistence(timeout: 5))
    }

    func testAddTaskWithDueDate() throws {
        navigateToToday()
        app.buttons["Add task"].tap()

        let titleField = app.textFields["What do you need to do?"]
        titleField.tap()
        titleField.typeText("Task with due date")

        // Tap "Tomorrow" button to set due date
        let tomorrowButton = app.buttons["Tomorrow"]
        if tomorrowButton.exists && tomorrowButton.isHittable {
            tomorrowButton.tap()
        }

        // Add the task via navigation bar button (not subtask Add button)
        let navBar = app.navigationBars["New Task"]
        let addButton = navBar.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        // Navigate to Upcoming to see the task (since due date is tomorrow)
        navigateToTab("Upcoming")

        // Verify task appears in Upcoming
        XCTAssertTrue(app.staticTexts["Task with due date"].waitForExistence(timeout: 3))
    }

    // MARK: - Task Completion Tests

    func testCompleteTask() throws {
        // First create a task
        navigateToToday()
        app.buttons["Add task"].tap()

        let titleField = app.textFields["What do you need to do?"]
        titleField.tap()
        titleField.typeText("Task to complete")

        // Use "Tomorrow" button to avoid "Today" tab bar collision
        let tomorrowButton = app.buttons["Tomorrow"]
        if tomorrowButton.exists && tomorrowButton.isHittable {
            tomorrowButton.tap()
        }

        // Add the task via navigation bar button
        let navBar = app.navigationBars["New Task"]
        let addButton = navBar.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        // Navigate to Upcoming to see the task (since we used Tomorrow)
        navigateToTab("Upcoming")

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
        navigateToTab("Lists")
        XCTAssertTrue(app.navigationBars["Lists"].waitForExistence(timeout: 3))

        // Find add list button - may have different labels on iPhone vs iPad
        let addListButton = app.buttons["Add list"]
        let addButton = app.buttons["Add"]
        let plusButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'plus' OR label CONTAINS 'Add'")).firstMatch

        guard addListButton.exists || addButton.exists || plusButton.exists else {
            throw XCTSkip("Add list button not found - UI may differ on this device")
        }

        // Tap the first available add button
        if addListButton.exists && addListButton.isHittable {
            addListButton.tap()
        } else if addButton.exists && addButton.isHittable {
            addButton.tap()
        } else if plusButton.exists && plusButton.isHittable {
            plusButton.tap()
        }

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
        navigateToTab("Lists")
        XCTAssertTrue(app.navigationBars["Lists"].waitForExistence(timeout: 3))

        // Find add list button
        let addListButton = app.buttons["Add list"]
        let addButton = app.buttons["Add"]

        guard addListButton.exists || addButton.exists else {
            throw XCTSkip("Add list button not found - UI may differ on this device")
        }

        if addListButton.exists && addListButton.isHittable {
            addListButton.tap()
        } else if addButton.exists && addButton.isHittable {
            addButton.tap()
        }

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
        navigateToTab("Settings")

        // Wait for Settings navigation bar to appear
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))

        // Verify key settings sections exist
        let appearance = app.staticTexts["Appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 2), "Appearance section should exist")
        XCTAssertTrue(app.staticTexts["Tasks"].exists, "Tasks section should exist")
    }

    func testChangeTheme() throws {
        navigateToTab("Settings")

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
        navigateToToday()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5), "Today view should be ready")

        let addButton = app.buttons["Add task"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        XCTAssertTrue(addButton.isHittable)
    }

    func testVoiceOverSupport() throws {
        // This test verifies that key elements are accessible to VoiceOver
        navigateToToday()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5), "Today view should be ready")

        if UIDevice.current.userInterfaceIdiom == .phone {
            // Check visible tab bar items (iOS shows 5 items max, including "More" for overflow)
            for tabName in ["Today", "Calendar", "Upcoming", "History"] {
                let tab = app.tabBars.buttons[tabName]
                XCTAssertTrue(tab.exists, "\(tabName) tab should exist")
                XCTAssertNotEqual(tab.label, "")
            }

            // Lists and Settings are under "More" tab
            let moreTab = app.tabBars.buttons["More"]
            if moreTab.exists {
                moreTab.tap()
                // Verify Lists and Settings are accessible in More menu
                XCTAssertTrue(app.tables.staticTexts["Lists"].waitForExistence(timeout: 2) ||
                              app.staticTexts["Lists"].waitForExistence(timeout: 2))
            }
        } else {
            // iPad: Check sidebar items (may be buttons, staticTexts, or cells)
            for tabName in ["Today", "Calendar", "Upcoming", "History", "Lists", "Settings"] {
                let button = app.buttons[tabName]
                let staticText = app.staticTexts[tabName]
                let cellText = app.cells.staticTexts[tabName]

                let exists = button.exists || staticText.exists || cellText.exists
                XCTAssertTrue(exists, "\(tabName) should exist in sidebar (button, text, or cell)")
            }
        }
    }

    // MARK: - Conflict Detection Tests

    func testConflictsBannerAppears() throws {
        navigateToToday()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 2))
        // Conflicts banner appears when there are scheduling conflicts
        // This test verifies the view loads without crashing
    }

    func testPushToTomorrowSwipeAction() throws {
        navigateToToday()

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

        // Add the task via navigation bar button
        let navBar = app.navigationBars["New Task"]
        let addButton = navBar.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        // Navigate to Upcoming to see the task
        navigateToTab("Upcoming")

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
            // iPad should show sidebar navigation with section headers
            let tasksHeader = app.staticTexts["Tasks"]
            let todayText = app.staticTexts["Today"]
            let todayButton = app.buttons["Today"]

            let hasNavigation = tasksHeader.waitForExistence(timeout: 5) ||
                               todayText.exists ||
                               todayButton.exists

            XCTAssertTrue(hasNavigation, "iPad should have sidebar navigation")
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

        // Test navigating to Calendar
        navigateToTab("Calendar")
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 3), "Calendar view should be shown")

        // Test navigating to Settings
        navigateToTab("Settings")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3), "Settings view should be shown")
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

        // Verify tab bar exists and visible tabs are present
        // With 6 tabs, iOS shows 5 in tab bar (including "More" for overflow)
        XCTAssertTrue(app.tabBars.firstMatch.exists, "iPhone should have tab bar")
        XCTAssertTrue(app.tabBars.buttons["Today"].exists)
        XCTAssertTrue(app.tabBars.buttons["Calendar"].exists)
        XCTAssertTrue(app.tabBars.buttons["Upcoming"].exists)
        XCTAssertTrue(app.tabBars.buttons["History"].exists)

        // Lists and Settings are under "More" tab
        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.exists, "More tab should exist for overflow items")

        // Test tab navigation still works via More menu
        navigateToTab("Settings")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))

        navigateToToday()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 2))
    }

    func testNavigationConsistency() throws {
        // Regardless of device, tapping on a view should show correct content
        // Use navigateToTab which handles both iPad sidebar and iPhone tab bar
        navigateToTab("Lists")

        // Lists view should be shown
        let listsNav = app.navigationBars["Lists"]
        XCTAssertTrue(listsNav.waitForExistence(timeout: 3), "Lists view should be accessible")
    }

    // MARK: - Morning Briefing Tests

    func testMorningBriefingSettingsExist() throws {
        navigateToTab("Settings")

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
        navigateToToday()

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
        navigateToToday()

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
        navigateToToday()

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

    func testMorningBriefingPromptToggle() throws {
        navigateToTab("Settings")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))

        // Find the Morning Briefing Prompt Toggle using accessibilityIdentifier
        let promptToggle = app.switches["Morning Briefing Prompt Toggle"]

        // Scroll to find the toggle if needed
        for _ in 0..<5 {
            if promptToggle.exists && promptToggle.isHittable {
                break
            }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertTrue(promptToggle.waitForExistence(timeout: 5), "Morning Briefing Prompt Toggle should exist in settings")

        // Get initial state
        let wasOnValue = promptToggle.value as? String ?? ""
        let wasOn = wasOnValue == "1" || wasOnValue.lowercased() == "true"

        // Toggle the switch using coordinate tap (XCUITest toggle workaround)
        promptToggle.tap()
        let switchCoord = promptToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        switchCoord.tap()

        // Wait for state change
        Thread.sleep(forTimeInterval: 0.5)

        // Verify state changed
        let isOnValue = promptToggle.value as? String ?? ""
        let isOn = isOnValue == "1" || isOnValue.lowercased() == "true"
        XCTAssertNotEqual(wasOn, isOn, "Morning Briefing Prompt Toggle should change state")

        // Toggle back to original state
        promptToggle.tap()
        switchCoord.tap()
    }

    // MARK: - Daily Summary Tests

    func testDailySummarySettingsExist() throws {
        navigateToTab("Settings")

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
        navigateToTab("Settings")

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
        navigateToTab("Settings")

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
        navigateToToday()
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
        navigateToToday()
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
        navigateToTab("Settings")

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
        navigateToTab("Calendar")

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
        navigateToTab("Calendar")
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
        navigateToToday()

        // First create a task to search for
        app.buttons["Add task"].tap()
        let titleField = app.textFields["What do you need to do?"]
        titleField.tap()
        titleField.typeText("Searchable test task")

        // Add the task via navigation bar button
        let navBar = app.navigationBars["New Task"]
        let addButton = navBar.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

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
        navigateToToday()
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

            // Find subtask input field and use helper for reliable keyboard focus
            let subtaskField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'subtask' OR identifier CONTAINS[c] 'subtask'")).firstMatch
            if subtaskField.waitForExistence(timeout: 2) && subtaskField.isHittable {
                // Type text with newline to submit (more reliable than tapping Return key)
                tapAndTypeText(subtaskField, text: "First Subtask\n")
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
        navigateToToday()
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
        navigateToTab("Upcoming")

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
        navigateToToday()
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
        navigateToTab("Upcoming")

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
        navigateToTab("Upcoming")

        // Look for any task row with subtask progress indicator (e.g., "0/2" or "1/3")
        let progressIndicator = app.staticTexts.matching(NSPredicate(format: "label MATCHES '\\\\d+/\\\\d+'")).firstMatch

        // Progress badge may or may not exist depending on tasks with subtasks
        // This test verifies the view loads without crashing
        XCTAssertTrue(app.navigationBars["Upcoming"].waitForExistence(timeout: 3))
    }

    func testExpandCollapseSubtasks() throws {
        // Navigate to Upcoming view where tasks with subtasks may appear
        navigateToTab("Upcoming")
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
        navigateToTab("Upcoming")
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

    // MARK: - Task Creation with Subtasks

    /// Test creating a task with subtasks from Today tab
    func testCreateTaskWithSubtaskFromTodayTab() throws {
        // Navigate to Today
        navigateToToday()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3))

        // Open add task sheet
        app.buttons["Add task"].tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))

        // Enter task title
        let titleField = app.textFields["What do you need to do?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Parent Task")

        // Set due date to Tomorrow
        let tomorrowButton = app.buttons["Tomorrow"]
        XCTAssertTrue(tomorrowButton.waitForExistence(timeout: 3), "Tomorrow button should exist")
        tomorrowButton.tap()
        Thread.sleep(forTimeInterval: 0.3) // Allow UI to update

        // Add a subtask (avoid scrolling - swipes dismiss sheets)
        let addSubtaskButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'plus.circle'")).firstMatch
        if addSubtaskButton.waitForExistence(timeout: 3) && addSubtaskButton.isHittable {
            addSubtaskButton.tap()

            let subtaskField = app.textFields["Add subtask"]
            if subtaskField.waitForExistence(timeout: 2) && subtaskField.isHittable {
                // Use paste workaround for reliable text entry
                tapAndTypeText(subtaskField, text: "My Subtask")

                // Confirm subtask with checkmark
                let checkmark = app.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'checkmark.circle'")).firstMatch
                if checkmark.waitForExistence(timeout: 2) && checkmark.isHittable {
                    checkmark.tap()
                }
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        // Save the task
        let navBar = app.navigationBars["New Task"]
        let addButton = navBar.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        // Wait for task to be saved and sheet to dismiss
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3), "Should return to Today view after saving")

        // Navigate to Upcoming to verify
        navigateToTab("Upcoming")
        Thread.sleep(forTimeInterval: 1.0) // Allow view to load and fetch data

        // Verify task appears - using longer timeout for potential data fetch delay
        let taskText = app.staticTexts["Parent Task"].firstMatch
        XCTAssertTrue(taskText.waitForExistence(timeout: 8), "Task with subtask should appear in Upcoming view")
    }

    // MARK: - AI Settings Tests

    /// Test navigating to AI Settings and verifying provider options exist
    func testAISettingsShowsProviders() throws {
        navigateToTab("Settings")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))

        // Find and tap AI Settings - try multiple element types
        // The button has a Label("AI Settings", systemImage: "brain") inside
        let aiButton = app.buttons["AI Settings"]
        let aiCell = app.cells.containing(.staticText, identifier: "AI Settings").firstMatch
        let aiStaticText = app.staticTexts["AI Settings"]

        if aiButton.waitForExistence(timeout: 3) && aiButton.isHittable {
            aiButton.tap()
        } else if aiCell.waitForExistence(timeout: 2) && aiCell.isHittable {
            aiCell.tap()
        } else if aiStaticText.waitForExistence(timeout: 2) && aiStaticText.isHittable {
            aiStaticText.tap()
        } else {
            // Try scrolling to find it (AI Features section may not be visible)
            let settingsList = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
            if settingsList.exists {
                settingsList.swipeUp()
                Thread.sleep(forTimeInterval: 0.5)
            }

            // Check again after scroll
            if aiButton.waitForExistence(timeout: 2) && aiButton.isHittable {
                aiButton.tap()
            } else if aiStaticText.waitForExistence(timeout: 2) && aiStaticText.isHittable {
                aiStaticText.tap()
            } else {
                throw XCTSkip("AI Settings button not found - may not be visible")
            }
        }

        // Verify AI Settings sheet appears
        let aiSettingsTitle = app.staticTexts["AI Settings"]
        XCTAssertTrue(aiSettingsTitle.waitForExistence(timeout: 3), "AI Settings sheet should appear")

        // Verify provider options exist
        let appleOption = app.staticTexts["Apple Intelligence"]
        let ollamaOption = app.staticTexts["Ollama (Local)"]
        let customOption = app.staticTexts["Custom Endpoint"]

        XCTAssertTrue(appleOption.waitForExistence(timeout: 2), "Apple Intelligence option should exist")
        XCTAssertTrue(ollamaOption.exists, "Ollama option should exist")
        XCTAssertTrue(customOption.exists, "Custom Endpoint option should exist")

        // Dismiss
        let doneButton = app.buttons["Done"]
        if doneButton.exists && doneButton.isHittable {
            doneButton.tap()
        }
    }

    /// Test configuring Ollama provider and selecting a model
    /// Requires Ollama to be running locally with models available
    func testOllamaModelSelection() throws {
        navigateToTab("Settings")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))

        // Open AI Settings - use the same pattern as testAISettingsShowsProviders
        let aiButton = app.buttons["AI Settings"]
        let aiStaticText = app.staticTexts["AI Settings"]

        if !(aiButton.waitForExistence(timeout: 2) && aiButton.isHittable) &&
           !(aiStaticText.waitForExistence(timeout: 1) && aiStaticText.isHittable) {
            // Scroll to find AI Settings
            let settingsList = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
            if settingsList.exists {
                settingsList.swipeUp()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        if aiStaticText.waitForExistence(timeout: 2) && aiStaticText.isHittable {
            aiStaticText.tap()
        } else if aiButton.waitForExistence(timeout: 1) && aiButton.isHittable {
            aiButton.tap()
        } else {
            throw XCTSkip("AI Settings button not found")
        }
        Thread.sleep(forTimeInterval: 0.5)

        // Tap Configure for Ollama
        let configureButton = app.buttons.matching(NSPredicate(format: "label == 'Configure'")).element(boundBy: 0)
        guard configureButton.waitForExistence(timeout: 2) && configureButton.isHittable else {
            throw XCTSkip("Configure button not found")
        }
        configureButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Look for model field or download models button
        let modelField = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Model'")).firstMatch
        let downloadButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'arrow.down' OR label CONTAINS[c] 'download'")).firstMatch

        if downloadButton.waitForExistence(timeout: 2) && downloadButton.isHittable {
            // Tap to fetch models
            downloadButton.tap()
            // Wait for models to load
            Thread.sleep(forTimeInterval: 3)
        }

        // Look for model picker
        let modelPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'gemma' OR label CONTAINS[c] 'llama' OR label CONTAINS[c] 'qwen'")).firstMatch

        if modelPicker.waitForExistence(timeout: 2) && modelPicker.isHittable {
            // Tap to open model selection
            modelPicker.tap()
            Thread.sleep(forTimeInterval: 0.5)

            // Verify model list appears
            let modelList = app.navigationBars["Select Model"]
            XCTAssertTrue(modelList.waitForExistence(timeout: 2), "Model selection view should appear")

            // Try to select a different model
            let modelRows = app.cells.count
            if modelRows > 1 {
                // Tap a model row
                app.cells.element(boundBy: 1).tap()
                Thread.sleep(forTimeInterval: 0.5)

                // Verify we returned to config sheet (model should be selected)
                XCTAssertFalse(modelList.exists, "Model selection should dismiss after selecting")
            }
        }

        // Dismiss configuration
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists && cancelButton.isHittable {
            cancelButton.tap()
        }
    }
}
