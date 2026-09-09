import XCTest
@testable import Gate

@MainActor
final class EmergencyBypassTests: XCTestCase {
    private func preparedModel() throws -> GateModel {
        let model = GateModel()
        guard model.isDemo else {
            throw NSError(domain: "GateTests", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "App-hosted tests must launch with --demo."])
        }
        try model.setEmergencyPasscode("0123", confirmation: "0123", current: nil)
        model.beginChallenge(for: model.apps[0])
        return model
    }

    func testVerificationAndCancellationGrantNothingAndCannotReuseAuthorization() throws {
        let model = try preparedModel()
        let session = try XCTUnwrap(model.challenge)
        XCTAssertThrowsError(try model.authorizeEmergencyUnlock("9999", for: session))
        XCTAssertNil(try model.bypass("0123", for: session))
        let options = try model.authorizeEmergencyUnlock("0123", for: session)
        XCTAssertTrue(model.state.grants.isEmpty)
        model.cancelEmergencyUnlock(for: session)
        XCTAssertThrowsError(try model.confirmEmergencyUnlock(.fifteenMinutes, options: options, for: session))
        let fresh = try model.authorizeEmergencyUnlock("0123", for: session)
        XCTAssertThrowsError(try model.confirmEmergencyUnlock(.fifteenMinutes, options: options, for: session))
        XCTAssertTrue(model.state.grants.isEmpty)
        XCTAssertNotNil(try model.confirmEmergencyUnlock(.fifteenMinutes, options: fresh, for: session))
        let grants = model.state.grants
        XCTAssertThrowsError(try model.confirmEmergencyUnlock(.fifteenMinutes, options: fresh, for: session))
        XCTAssertEqual(model.state.grants, grants)
        XCTAssertNil(model.grant(for: model.apps[1].id))
    }

    func testBackgroundAndNewChallengesInvalidateTheVerifiedCode() throws {
        let model = try preparedModel()
        let old = try XCTUnwrap(model.challenge)
        let options = try model.authorizeEmergencyUnlock("0123", for: old)
        model.leaveForeground()
        XCTAssertThrowsError(try model.confirmEmergencyUnlock(.fifteenMinutes, options: options, for: old))
        XCTAssertThrowsError(try model.authorizeEmergencyUnlock("0123", for: old))
        model.returnToForeground()
        let current = try XCTUnwrap(model.challenge)
        XCTAssertNotEqual(current.id, old.id)
        XCTAssertThrowsError(try model.confirmEmergencyUnlock(.fifteenMinutes, options: options, for: current))
        let fresh = try model.authorizeEmergencyUnlock("0123", for: current)
        model.beginChallenge(for: model.apps[1])
        XCTAssertThrowsError(try model.confirmEmergencyUnlock(.fifteenMinutes, options: fresh, for: current))
        XCTAssertTrue(model.state.grants.isEmpty)
    }

    func testChosenEmergencyWindowIsIndependentOfMathAndSettingsAndPracticePreserveIt() throws {
        let model = try preparedModel()
        model.setUnlockDuration(.fiveMinutes)
        model.beginChallenge(for: model.apps[0])
        let session = try XCTUnwrap(model.challenge)
        let now = ISO8601DateFormatter().date(from: "2026-09-09T12:00:00Z")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let options = try model.authorizeEmergencyUnlock("0123", for: session, now: now, calendar: calendar)
        XCTAssertNotNil(try model.confirmEmergencyUnlock(.today, options: options, for: session, now: now.addingTimeInterval(30)))
        let grant = try XCTUnwrap(model.state.grants.first)
        XCTAssertEqual(grant.expiresAt, options.dayEndsAt)
        XCTAssertEqual(grant.issuedAt, now.addingTimeInterval(30))
        XCTAssertEqual(model.unlockDuration, .fiveMinutes)
        model.beginSettingsChallenge()
        XCTAssertNotNil(try model.bypass("0123", for: XCTUnwrap(model.challenge)))
        XCTAssertEqual(model.state.grants, [grant])
        model.beginChallenge(for: nil)
        XCTAssertNotNil(try model.bypass("0123", for: XCTUnwrap(model.challenge)))
        XCTAssertEqual(model.state.grants, [grant])
        model.beginChallenge(for: model.apps[1])
        let math = try XCTUnwrap(model.challenge)
        model.setUnlockDuration(.thirtyMinutes)
        XCTAssertNotNil(try model.submit(String(math.problem.answer), for: math))
        let mathGrant = try XCTUnwrap(model.grant(for: model.apps[1].id))
        XCTAssertEqual(mathGrant.expiresAt.timeIntervalSince(mathGrant.issuedAt), 300)
        XCTAssertEqual(model.state.grants.first, grant)
    }

    func testDayRolloverAndCredentialChangesRequireReverification() throws {
        let model = try preparedModel()
        let session = try XCTUnwrap(model.challenge)
        let options = try model.authorizeEmergencyUnlock("0123", for: session)
        XCTAssertThrowsError(try model.confirmEmergencyUnlock(.today, options: options, for: session, now: options.dayEndsAt))
        try model.setEmergencyPasscode("4567", confirmation: "4567", current: "0123")
        XCTAssertThrowsError(try model.confirmEmergencyUnlock(.fifteenMinutes, options: options, for: session))
        let fresh = try model.authorizeEmergencyUnlock("4567", for: session)
        try model.removeEmergencyPasscode(current: "4567")
        XCTAssertThrowsError(try model.confirmEmergencyUnlock(.fifteenMinutes, options: fresh, for: session))
        XCTAssertTrue(model.state.grants.isEmpty)
    }
}
