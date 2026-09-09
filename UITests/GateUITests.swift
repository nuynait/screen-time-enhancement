import XCTest

final class GateUITests: XCTestCase {
    @MainActor
    func testEmergencyBypassAcrossAppSettingsAndPractice() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        let first = "11111111-1111-1111-1111-111111111111"
        let second = "22222222-2222-2222-2222-222222222222"
        app.buttons["solve-" + first].tap()
        XCTAssertFalse(app.buttons["emergency-bypass"].exists)
        app.buttons["Cancel"].tap()
        openSettings(app)
        setUpPasscode(app)
        let duration = app.buttons["unlock-duration-picker"]
        for _ in 0..<8 where !duration.isHittable { app.swipeDown() }
        duration.tap()
        app.buttons["5 minutes"].tap()
        app.buttons["Done"].tap()
        app.buttons["solve-" + first].tap()
        capture(app, "Calculation with emergency bypass")
        openBypass(app)
        capture(app, "Emergency passcode entry")
        app.buttons["cancel-passcode"].tap()
        XCTAssertFalse(app.staticTexts["unlock-success"].exists)
        openBypass(app)
        enterPasscode(app, "9999")
        XCTAssertTrue(app.staticTexts["passcode-feedback"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["unlock-success"].exists)
        enterPasscode(app, "0123")
        XCTAssertTrue(app.staticTexts["unlock-success"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Opened with your emergency passcode."].exists)
        XCTAssertFalse(app.staticTexts["47 × 63 = 2961"].exists)
        let remaining = app.staticTexts["unlock-countdown"].label
        XCTAssertTrue(remaining.hasPrefix("4:") || remaining == "5:00", remaining)
        capture(app, "App window opened with emergency passcode")
        app.buttons["finish-challenge"].tap()
        let countdown = app.staticTexts["countdown-" + first]
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["solve-" + second].exists)

        app.buttons["settings"].tap()
        openBypass(app)
        enterPasscode(app, "0123")
        XCTAssertTrue(app.staticTexts["calculation-example"].waitForExistence(timeout: 5))
        let practice = app.buttons["Try a practice calculation"]
        for _ in 0..<10 where !practice.isHittable { app.swipeUp() }
        practice.tap()
        openBypass(app)
        enterPasscode(app, "0123")
        XCTAssertTrue(app.staticTexts["unlock-success"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["unlock-success"].label, "Practice bypassed.")
        XCTAssertFalse(app.staticTexts["unlock-countdown"].exists)
        app.buttons["finish-challenge"].tap()
        XCTAssertTrue(app.buttons["lock-" + first].exists)
        XCTAssertTrue(app.buttons["solve-" + second].exists)
        // Preview passcodes are intentionally isolated from the persistent Keychain.
        app.terminate()
        app.launch()
        app.buttons["solve-" + first].tap()
        XCTAssertFalse(app.buttons["emergency-bypass"].exists)
    }

    @MainActor
    func testPasscodeManagementAndBackgroundDoNotLeaveAccessOpen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        openSettings(app)
        setUpPasscode(app)
        app.buttons["change-passcode"].tap()
        enterPasscode(app, "9999")
        XCTAssertTrue(app.staticTexts["passcode-feedback"].exists)
        enterPasscode(app, "0123")
        enterPasscode(app, "4567")
        enterPasscode(app, "4567")
        XCTAssertTrue(app.buttons["change-passcode"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["settings"].tap()
        openBypass(app)
        enterPasscode(app, "0123")
        XCTAssertTrue(app.staticTexts["passcode-feedback"].exists)
        let input = app.secureTextFields["passcode-entry"]
        input.tap()
        input.typeText("45")
        XCTAssertFalse(app.buttons["submit-passcode"].isEnabled)
        let otherApp = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        otherApp.launch()
        app.activate()
        // Returning creates a new challenge and dismisses its unfinished passcode sheet.
        XCTAssertTrue(app.staticTexts["challenge-refreshed"].waitForExistence(timeout: 5))
        XCTAssertFalse(input.exists)
        openBypass(app)
        XCTAssertFalse(app.buttons["submit-passcode"].isEnabled)
        enterPasscode(app, "4567")
        XCTAssertTrue(app.staticTexts["calculation-example"].waitForExistence(timeout: 5))
        otherApp.activate()
        app.activate()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["calculation-example"])
        waitForExpectations(timeout: 5)
        app.buttons["settings"].tap()
        openBypass(app)
        enterPasscode(app, "4567")
        let remove = app.buttons["remove-passcode"]
        for _ in 0..<8 where !remove.isHittable { app.swipeUp() }
        remove.tap()
        enterPasscode(app, "0123")
        XCTAssertTrue(app.staticTexts["passcode-feedback"].exists)
        app.buttons["cancel-passcode"].tap()
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        enterPasscode(app, "4567")
        XCTAssertTrue(app.buttons["set-passcode"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["settings"].tap()
        XCTAssertFalse(app.buttons["emergency-bypass"].exists)
        answerSettingsGate(app)
    }

    @MainActor
    func testEmergencyPasscodeAtLargestAccessibilitySize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openSettings(app)
        setUpPasscode(app)
        app.buttons["Done"].tap()
        app.buttons["settings"].tap()
        openBypass(app)
        capture(app, "Emergency bypass accessibility heading")
        enterPasscode(app, "0123")
        XCTAssertTrue(app.staticTexts["calculation-example"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func setUpPasscode(_ app: XCUIApplication) {
        let setup = app.buttons["set-passcode"]
        for _ in 0..<12 where !setup.isHittable { app.swipeUp() }
        capture(app, "Emergency bypass Settings")
        setup.tap()
        capture(app, "Choose emergency passcode")
        enterPasscode(app, "0123")
        enterPasscode(app, "9999")
        XCTAssertTrue(app.staticTexts["passcode-feedback"].waitForExistence(timeout: 3))
        enterPasscode(app, "0123")
        XCTAssertTrue(app.buttons["change-passcode"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openBypass(_ app: XCUIApplication) {
        let bypass = app.buttons["emergency-bypass"]
        XCTAssertTrue(bypass.waitForExistence(timeout: 5))
        for _ in 0..<8 where !bypass.isHittable { app.swipeUp() }
        bypass.tap()
        XCTAssertTrue(app.secureTextFields["passcode-entry"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func enterPasscode(_ app: XCUIApplication, _ code: String) {
        let input = app.secureTextFields["passcode-entry"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        for _ in 0..<8 where !input.isHittable { app.swipeUp() }
        input.tap()
        input.typeText(code)
        let submit = app.buttons["submit-passcode"]
        for _ in 0..<8 where !submit.isHittable { app.swipeUp() }
        if app.launchArguments.contains("UICTContentSizeCategoryAccessibilityXXXL") {
            capture(app, "Emergency passcode accessibility controls")
        }
        submit.tap()
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLeavingEachChallengeRefreshesNumbersAndRejectsThePreviousAnswer() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        let otherApp = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        let first = "11111111-1111-1111-1111-111111111111"
        let second = "22222222-2222-2222-2222-222222222222"
        for destination in ["settings", "app", "practice"] {
            switch destination {
            case "settings": app.buttons["settings"].tap()
            case "app": app.buttons["solve-" + first].tap()
            default:
                openSettings(app)
                let practice = app.buttons["Try a practice calculation"]
                for _ in 0..<8 where !practice.isHittable { app.swipeUp() }
                practice.tap()
            }
            let problem = app.staticTexts["problem"]
            XCTAssertTrue(problem.waitForExistence(timeout: 5))
            let oldExpression = problem.label
            let oldAnswer = answerToDisplayedCalculation(app)
            let answer = app.textFields["answer"]
            answer.tap()
            answer.typeText(oldAnswer)
            // Settings is present in the simulator; switching apps exercises the same lifecycle as Calculator.
            otherApp.launch()
            XCTAssertTrue(otherApp.wait(for: .runningForeground, timeout: 5))
            app.activate()
            expectation(for: NSPredicate(format: "exists == true AND label != %@", oldExpression), evaluatedWith: problem)
            waitForExpectations(timeout: 5)
            XCTAssertTrue(app.staticTexts["challenge-refreshed"].exists)
            XCTAssertFalse(app.buttons["submit-answer"].isEnabled)
            XCTAssertTrue((answer.value as? String ?? "").isEmpty || answer.value as? String == answer.placeholderValue)
            let refreshed = XCTAttachment(screenshot: app.screenshot())
            refreshed.name = "Fresh calculation after app switch " + destination
            refreshed.lifetime = .keepAlways
            add(refreshed)
            answer.tap()
            answer.typeText(oldAnswer)
            app.buttons["submit-answer"].tap()
            XCTAssertTrue(app.staticTexts["answer-feedback"].waitForExistence(timeout: 3))
            XCTAssertFalse(app.staticTexts["unlock-success"].exists)
            let newAnswer = answerToDisplayedCalculation(app)
            answer.tap()
            answer.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldAnswer.count) + newAnswer)
            app.buttons["submit-answer"].tap()
            if destination == "settings" {
                XCTAssertTrue(app.staticTexts["calculation-example"].waitForExistence(timeout: 5))
                app.buttons["Done"].tap()
            } else {
                XCTAssertTrue(app.staticTexts["unlock-success"].waitForExistence(timeout: 5))
                if destination == "app" {
                    otherApp.activate()
                    app.activate()
                    XCTAssertTrue(app.staticTexts["unlock-success"].exists)
                    XCTAssertTrue(app.staticTexts["unlock-countdown"].exists)
                    XCTAssertFalse(app.staticTexts["problem"].exists)
                }
                app.buttons["finish-challenge"].tap()
            }
            if destination == "app" { app.buttons["lock-" + first].tap() }
            XCTAssertTrue(app.buttons["solve-" + first].exists)
            XCTAssertTrue(app.buttons["solve-" + second].exists)
        }
    }

    @MainActor
    func testSettingsRequireCurrentCalculationOnEveryVisitWithoutUnlockingApps() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        app.buttons["settings"].tap()
        XCTAssertEqual(app.staticTexts["problem"].label, "47 times 63")
        XCTAssertEqual(app.buttons["submit-answer"].label, "Open Settings")
        XCTAssertFalse(app.buttons["operation-addition"].exists)
        let gate = XCTAttachment(screenshot: app.screenshot())
        gate.name = "Calculation before Settings"
        gate.lifetime = .keepAlways
        add(gate)
        app.textFields["answer"].tap()
        app.textFields["answer"].typeText("0")
        app.buttons["submit-answer"].tap()
        XCTAssertTrue(app.staticTexts["answer-feedback"].exists)
        XCTAssertFalse(app.staticTexts["calculation-example"].exists)
        app.buttons["Cancel"].tap()
        openSettings(app)
        app.segmentedControls["first-number-digits"].buttons["3 digits"].tap()
        app.segmentedControls["second-number-digits"].buttons["3 digits"].tap()
        app.buttons["Done"].tap()
        for _ in 0..<2 {
            app.buttons["settings"].tap()
            XCTAssertEqual(app.staticTexts["problem"].label, "247 times 163")
            XCTAssertFalse(app.staticTexts["calculation-example"].exists)
            app.buttons["Cancel"].tap()
        }
        openSettings(app)
        app.buttons["operation-addition"].tap()
        app.buttons["Done"].tap()
        app.buttons["settings"].tap()
        XCTAssertEqual(app.staticTexts["problem"].label, "247 plus 163")
        answerSettingsGate(app)
        XCUIDevice.shared.press(.home)
        app.activate()
        let closed = NSPredicate(format: "exists == false")
        expectation(for: closed, evaluatedWith: app.staticTexts["calculation-example"])
        waitForExpectations(timeout: 5)
        app.buttons["settings"].tap()
        XCTAssertEqual(app.staticTexts["problem"].label, "247 plus 163")
        answerSettingsGate(app)
        app.buttons["Done"].tap()
        for id in ["11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222"] {
            XCTAssertTrue(app.buttons["solve-" + id].exists)
            XCTAssertFalse(app.buttons["lock-" + id].exists)
        }
    }

    @MainActor
    func testCalculationSettingsReachEveryOperationAndMixedDigitChallenge() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "Home with default calculation"
        home.lifetime = .keepAlways
        add(home)
        let first = "11111111-1111-1111-1111-111111111111"
        let second = "22222222-2222-2222-2222-222222222222"
        openSettings(app)
        XCTAssertEqual(app.staticTexts["calculation-example"].label, "Example: 47 times 63")
        app.segmentedControls["first-number-digits"].buttons["3 digits"].tap()
        app.segmentedControls["second-number-digits"].buttons["3 digits"].tap()

        let cases = [("multiplication", "247 times 163", "40261"),
                     ("addition", "247 plus 163", "410"),
                     ("subtraction", "247 minus 163", "84"),
                     ("division", "864 divided by 216", "4")]
        for (operation, expression, result) in cases {
            app.buttons["operation-" + operation].tap()
            XCTAssertEqual(app.staticTexts["calculation-example"].label, "Example: " + expression)
            let settings = XCTAttachment(screenshot: app.screenshot())
            settings.name = "Calculation settings " + operation
            settings.lifetime = .keepAlways
            add(settings)
            app.buttons["Done"].tap()
            app.buttons["solve-" + first].tap()
            XCTAssertEqual(app.staticTexts["problem"].label, expression)
            app.textFields["answer"].tap()
            app.textFields["answer"].typeText(result)
            app.buttons["submit-answer"].tap()
            XCTAssertTrue(app.staticTexts["unlock-success"].waitForExistence(timeout: 5))
            app.buttons["finish-challenge"].tap()
            XCTAssertTrue(app.buttons["solve-" + second].exists)
            app.buttons["lock-" + first].tap()
            openSettings(app)
        }
        app.segmentedControls["first-number-digits"].buttons["2 digits"].tap()
        XCTAssertEqual(app.staticTexts["calculation-example"].label, "Example: 432 divided by 24")
        app.buttons["operation-multiplication"].tap()
        XCTAssertEqual(app.staticTexts["calculation-example"].label, "Example: 47 times 163")
        app.buttons["Done"].tap()
        app.buttons["solve-" + first].tap()
        XCTAssertEqual(app.staticTexts["problem"].label, "47 times 163")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["solve-" + first].exists)
        openSettings(app)
        let practice = app.buttons["Try a practice calculation"]
        for _ in 0..<8 where !practice.isHittable { app.swipeUp() }
        practice.tap()
        XCTAssertTrue(app.textFields["answer"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["problem"].label, "47 times 163")
        XCTAssertEqual(app.buttons["submit-answer"].label, "Check answer")
        app.textFields["answer"].tap()
        app.textFields["answer"].typeText("7661")
        app.buttons["submit-answer"].tap()
        XCTAssertTrue(app.staticTexts["unlock-success"].waitForExistence(timeout: 5))
        app.buttons["finish-challenge"].tap()
        XCTAssertTrue(app.buttons["solve-" + first].exists)
        XCTAssertTrue(app.buttons["solve-" + second].exists)
    }

    @MainActor
    func testCalculationControlsAtLargestAccessibilityTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openSettings(app)
        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "Calculation settings largest text top"
        top.lifetime = .keepAlways
        add(top)
        let divide = app.buttons["operation-division"]
        for _ in 0..<5 where !divide.isHittable { app.swipeUp() }
        divide.tap()
        for identifier in ["first-number-digits", "second-number-digits"] {
            let picker = app.buttons[identifier]
            for _ in 0..<5 where !picker.isHittable { app.swipeUp() }
            picker.tap()
            app.buttons["3 digits"].tap()
        }
        let controls = XCTAttachment(screenshot: app.screenshot())
        controls.name = "Calculation settings largest text controls"
        controls.lifetime = .keepAlways
        add(controls)
        app.buttons["Done"].tap()
        let solve = app.buttons["solve-11111111-1111-1111-1111-111111111111"]
        for _ in 0..<5 where !solve.isHittable { app.swipeUp() }
        solve.tap()
        XCTAssertEqual(app.staticTexts["problem"].label, "864 divided by 216")
    }

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
            openSettings(app)
            for _ in 0..<4 where !app.buttons["manage-notifications"].isHittable { app.swipeUp() }
            XCTAssertEqual(app.buttons["manage-notifications"].label, "Notification settings")
            app.buttons["manage-notifications"].tap()
        }
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 5))
        XCTAssertFalse(springboard.alerts.firstMatch.exists)
        // The simulator opens Settings but does not expose per-app notification toggles.
        app.activate()
        // Settings access expires when Gate backgrounds for the system Settings handoff.
        XCTAssertFalse(app.staticTexts["calculation-example"].exists)
        XCTAssertEqual(app.staticTexts["notification-guidance"].exists, needsPermission)
    }

    @MainActor
    func testConfiguredDurationReachesChallengeAndLeavesExistingWindowAlone() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        let first = "11111111-1111-1111-1111-111111111111"
        let second = "22222222-2222-2222-2222-222222222222"
        openSettings(app)
        app.buttons["unlock-duration-picker"].tap()
        app.buttons["5 minutes"].tap()
        let settings = XCTAttachment(screenshot: app.screenshot())
        settings.name = "Configurable unlock time"
        settings.lifetime = .keepAlways
        add(settings)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Solve one calculation to earn 5 minutes in an app."].exists)
        app.buttons["solve-" + first].tap()
        XCTAssertEqual(app.buttons["submit-answer"].label, "Unlock for 5 minutes")
        app.textFields["answer"].tap()
        app.textFields["answer"].typeText("2961")
        app.buttons["submit-answer"].tap()
        XCTAssertTrue(app.staticTexts["unlock-success"].waitForExistence(timeout: 5))
        app.buttons["finish-challenge"].tap()
        openSettings(app)
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

    @MainActor
    private func openSettings(_ app: XCUIApplication) {
        app.buttons["settings"].tap()
        answerSettingsGate(app)
    }

    @MainActor
    private func answerSettingsGate(_ app: XCUIApplication) {
        XCTAssertTrue(app.textFields["answer"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["submit-answer"].label, "Open Settings")
        let result = answerToDisplayedCalculation(app)
        let answer = app.textFields["answer"]
        for _ in 0..<5 where !answer.isHittable { app.swipeUp() }
        answer.tap()
        answer.typeText(result)
        app.buttons["submit-answer"].tap()
        XCTAssertTrue(app.staticTexts["calculation-example"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func answerToDisplayedCalculation(_ app: XCUIApplication) -> String {
        let expression = app.staticTexts["problem"].label
        let numbers = expression.split(separator: " ").compactMap { Int($0) }
        guard numbers.count == 2 else { XCTFail("Unexpected calculation: \(expression)"); return "" }
        let result: Int
        if expression.contains("times") { result = numbers[0] * numbers[1] }
        else if expression.contains("plus") { result = numbers[0] + numbers[1] }
        else if expression.contains("minus") { result = numbers[0] - numbers[1] }
        else if expression.contains("divided by") { result = numbers[0] / numbers[1] }
        else { XCTFail("Unexpected operation: \(expression)"); return "" }
        return String(result)
    }
}
