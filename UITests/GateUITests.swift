import XCTest

final class GateUITests: XCTestCase {
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
