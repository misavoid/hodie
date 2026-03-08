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

        let titleField = app.textFields["Task title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("Focus Task")
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
        let titleField = app.textFields["Task title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("Rollover Task")
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

    private func tapTab(app: XCUIApplication, label: String) {
        let tabButton = app.tabBars.buttons[label]
        if tabButton.waitForExistence(timeout: 1) {
            tabButton.tap()
        }
    }
}
