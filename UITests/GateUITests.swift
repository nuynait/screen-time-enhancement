import XCTest

final class GateUITests: XCTestCase {
    @MainActor
    func testNotificationPermissionAndSettingsHandoff() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting", "--test-notifications"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // A fresh test installation exercises either decision; reruns reuse the OS's saved choice.
        let prompt = springboard.alerts.firstMatch
        if prompt.waitForExistence(timeout: 5) {
            let screenshot = XCTAttachment(screenshot: springboard.screenshot())
            screenshot.name = "First notification permission request"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let grantPermission = ProcessInfo.processInfo.environment["GATE_NOTIFICATION_TEST_RESPONSE"] == "allow"
            if grantPermission { prompt.buttons["Allow"].tap() }
            else { prompt.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' AND label != 'Allow'")).firstMatch.tap() }
            let guidance = app.staticTexts["notification-guidance"]
            let expected = NSPredicate(format: "exists == %@", NSNumber(value: !grantPermission))
            expectation(for: expected, evaluatedWith: guidance)
            waitForExpectations(timeout: 5)
            XCTAssertEqual(app.state, .runningForeground)
            XCTAssertFalse(app.alerts["Gate needs attention"].exists)
        }
        let needsPermission = app.staticTexts["notification-guidance"].exists
        if needsPermission {
            let button = app.buttons["allow-notifications"]
            if !button.isHittable { app.swipeUp() }
            let denied = XCTAttachment(screenshot: app.screenshot())
            denied.name = "Notifications disabled guidance"
            denied.lifetime = .keepAlways
            add(denied)
            button.tap()
        } else {
            XCTAssertFalse(app.buttons["allow-notifications"].exists)
            app.buttons["settings"].tap()
            XCTAssertEqual(app.buttons["manage-notifications"].label, "Notification settings")
            app.buttons["manage-notifications"].tap()
        }
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 5))
        XCTAssertFalse(springboard.alerts.firstMatch.exists)
        // The simulator opens Settings but does not expose per-app notification toggles.
        app.activate()
        if !needsPermission { app.buttons["Done"].tap() }
        XCTAssertEqual(app.staticTexts["notification-guidance"].exists, needsPermission)
    }

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
