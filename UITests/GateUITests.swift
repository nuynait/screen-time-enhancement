import XCTest

final class GateUITests: XCTestCase {
    @MainActor
    func testConfiguredDurationReachesChallengeAndLeavesExistingWindowAlone() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        let first = "11111111-1111-1111-1111-111111111111"
        let second = "22222222-2222-2222-2222-222222222222"
        app.buttons["settings"].tap()
        app.buttons["unlock-duration-picker"].tap()
        app.buttons["5 minutes"].tap()
        let settings = XCTAttachment(screenshot: app.screenshot())
        settings.name = "Configurable unlock time"
        settings.lifetime = .keepAlways
        add(settings)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Solve one multiplication to earn 5 minutes in an app."].exists)
        app.buttons["solve-" + first].tap()
        XCTAssertEqual(app.buttons["submit-answer"].label, "Unlock for 5 minutes")
        app.textFields["answer"].tap()
        app.textFields["answer"].typeText("2961")
        app.buttons["submit-answer"].tap()
        XCTAssertTrue(app.staticTexts["unlock-success"].waitForExistence(timeout: 5))
        app.buttons["finish-challenge"].tap()
        app.buttons["settings"].tap()
        app.buttons["unlock-duration-picker"].tap()
        app.buttons["30 minutes"].tap()
        app.buttons["Done"].tap()
        let remaining = app.staticTexts["countdown-" + first].value as? String ?? "Missing countdown value"
        XCTAssertTrue(remaining.hasPrefix("4:") || remaining.hasPrefix("5:"), remaining)
        app.buttons["solve-" + second].tap()
        XCTAssertEqual(app.buttons["submit-answer"].label, "Unlock for 30 minutes")
    }

    @MainActor
    func testWrongAnswerStaysLockedThenCorrectAnswerOpensOnlyOneApp() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        let first = "11111111-1111-1111-1111-111111111111"
        let second = "22222222-2222-2222-2222-222222222222"
        app.buttons["solve-" + first].tap()
        let answer = app.textFields["answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        answer.tap()
        answer.typeText("100")
        app.buttons["submit-answer"].tap()
        XCTAssertTrue(app.staticTexts["answer-feedback"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["unlock-success"].exists)
        answer.tap()
        answer.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "2961")
        app.buttons["submit-answer"].tap()
        XCTAssertTrue(app.staticTexts["unlock-success"].waitForExistence(timeout: 5))
        let success = XCTAttachment(screenshot: app.screenshot())
        success.name = "Correct answer opens a window"
        success.lifetime = .keepAlways
        add(success)
        app.buttons["finish-challenge"].tap()
        XCTAssertTrue(app.buttons["lock-" + first].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["solve-" + second].exists)
        app.buttons["lock-" + first].tap()
        XCTAssertTrue(app.buttons["solve-" + first].exists)
    }

    @MainActor
    func testCancellingChallengeDoesNotGrantAccess() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting", "--challenge"]
        app.launch()
        XCTAssertTrue(app.textFields["answer"].waitForExistence(timeout: 5))
        let challenge = XCTAttachment(screenshot: app.screenshot())
        challenge.name = "Multiplication challenge"
        challenge.lifetime = .keepAlways
        add(challenge)
        app.buttons["Cancel"].tap()
        let first = "11111111-1111-1111-1111-111111111111"
        XCTAssertTrue(app.buttons["solve-" + first].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["lock-" + first].exists)
    }
}
