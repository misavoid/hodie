import XCTest

final class HodieUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturePlanFocusFlow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UI-TESTING")
        app.launch()

        tapTab(app: app, label: "Inbox")

        let titleField = quickCaptureTitleField(in: app)
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("Focus Task")
        selectTaskType(app: app, label: "Task")
        app.buttons["Add to Inbox"].tap()

        tapTab(app: app, label: "Today")
        app.buttons["Plan from Inbox"].tap()
        let taskButton = app.buttons["Focus Task"]
        XCTAssertTrue(taskButton.waitForExistence(timeout: 2))
        taskButton.tap()
        app.buttons["Save"].tap()

        let plannedCell = app.staticTexts["Focus Task"]
        XCTAssertTrue(plannedCell.waitForExistence(timeout: 2))

        let focusButton = app.buttons["Start focus for Focus Task"]
        XCTAssertTrue(focusButton.waitForExistence(timeout: 2))
        focusButton.tap()

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2))
        doneButton.tap()

        tapTab(app: app, label: "Review")
        XCTAssertTrue(app.staticTexts["Completed: 1"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testReviewRolloverFlow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UI-TESTING")
        app.launch()

        tapTab(app: app, label: "Inbox")
        let titleField = quickCaptureTitleField(in: app)
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("Rollover Task")
        selectTaskType(app: app, label: "Task")
        app.buttons["Add to Inbox"].tap()

        tapTab(app: app, label: "Today")
        app.buttons["Plan from Inbox"].tap()
        let taskButton = app.buttons["Rollover Task"]
        XCTAssertTrue(taskButton.waitForExistence(timeout: 2))
        taskButton.tap()
        app.buttons["Save"].tap()

        tapTab(app: app, label: "Review")
        XCTAssertTrue(app.staticTexts["Unfinished: 1"].waitForExistence(timeout: 2))
        app.buttons["Rollover unfinished"].tap()
        app.buttons["Move to tomorrow"].tap()
        XCTAssertTrue(app.staticTexts["Unfinished: 0"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testScheduledReminderSectionShowsOriginList() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED-REMINDER-FIXTURE"])
        app.launch()

        tapTab(app: app, label: "Inbox")
        let sectionLabel = app.staticTexts["Scheduled & Recurring Reminders"]
        XCTAssertTrue(sectionLabel.waitForExistence(timeout: 2))
        sectionLabel.tap()

        let listBadge = app.staticTexts["From Fixture List"]
        XCTAssertTrue(listBadge.waitForExistence(timeout: 2))

        sectionLabel.tap()
        XCTAssertFalse(listBadge.waitForExistence(timeout: 1))
    }

    @MainActor
    func testQuickCaptureRequiresTaskTypeSelection() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UI-TESTING")
        app.launch()

        tapTab(app: app, label: "Inbox")
        let titleField = quickCaptureTitleField(in: app)
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("Type Required Task")

        let addButton = app.buttons["Add to Inbox"]
        XCTAssertFalse(addButton.isEnabled)

        selectTaskType(app: app, label: "Task")
        XCTAssertTrue(addButton.isEnabled)
    }

    @MainActor
    func testQuickCaptureSupportsMultilineTitle() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UI-TESTING")
        app.launch()

        tapTab(app: app, label: "Inbox")
        let titleField = quickCaptureTitleField(in: app)
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("Line One")
        titleField.typeText("\nSecond Line")

        guard let value = titleField.value as? String else {
            XCTFail("Expected title field to expose string value")
            return
        }
        XCTAssertTrue(value.contains("Line One"))
        XCTAssertTrue(value.contains("Second Line"))
    }

    private func tapTab(app: XCUIApplication, label: String) {
        let tabButton = app.tabBars.buttons[label]
        if tabButton.waitForExistence(timeout: 1) {
            tabButton.tap()
        }
    }

    private func quickCaptureTitleField(in app: XCUIApplication) -> XCUIElement {
        let identifier = "quickCapture.title"
        if app.textViews[identifier].exists {
            return app.textViews[identifier]
        } else if app.textFields[identifier].exists {
            return app.textFields[identifier]
        }
        return app.textFields["Task title"]
    }

    private func selectTaskType(app: XCUIApplication, label: String) {
        let button = app.segmentedControls.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 1))
        button.tap()
    }
}
