import XCTest
@testable import Gate

@MainActor
final class EmergencyBypassTests: XCTestCase {
    func testWrongStaleAndDuplicatePasscodesNeverCreateAnotherGrant() throws {
        let model = GateModel()
        XCTAssertTrue(model.isDemo, "App-hosted tests must launch with --demo.")
        guard model.isDemo else { return }
        try model.setEmergencyPasscode("0123", confirmation: "0123", current: nil)
        model.beginChallenge(for: model.apps[0])
        let old = try XCTUnwrap(model.challenge)
        XCTAssertThrowsError(try model.bypass("9999", for: old))
        XCTAssertTrue(model.state.grants.isEmpty)
        model.leaveForeground()
        XCTAssertNil(try model.bypass("0123", for: old))
        model.returnToForeground()
        let current = try XCTUnwrap(model.challenge)
        XCTAssertNotEqual(current.id, old.id)
        XCTAssertNil(try model.bypass("0123", for: old))
        XCTAssertTrue(model.state.grants.isEmpty)
        XCTAssertNotNil(try model.bypass("0123", for: current))
        let grants = model.state.grants
        XCTAssertNil(try model.bypass("0123", for: current))
        XCTAssertEqual(model.state.grants, grants)
        XCTAssertNil(model.grant(for: model.apps[1].id))
    }

    func testBypassUsesOfferedDurationAndSettingsAndPracticePreserveTheWindow() throws {
        let model = GateModel()
        XCTAssertTrue(model.isDemo)
        guard model.isDemo else { return }
        try model.setEmergencyPasscode("0123", confirmation: "0123", current: nil)
        model.setUnlockDuration(.fiveMinutes)
        model.beginChallenge(for: model.apps[0])
        let session = try XCTUnwrap(model.challenge)
        model.setUnlockDuration(.thirtyMinutes)
        XCTAssertNotNil(try model.bypass("0123", for: session))
        let grant = try XCTUnwrap(model.grant(for: model.apps[0].id))
        XCTAssertEqual(grant.expiresAt.timeIntervalSince(grant.issuedAt), 300)
        model.beginSettingsChallenge()
        XCTAssertNotNil(try model.bypass("0123", for: XCTUnwrap(model.challenge)))
        XCTAssertEqual(model.state.grants, [grant])
        model.beginChallenge(for: nil)
        XCTAssertNotNil(try model.bypass("0123", for: XCTUnwrap(model.challenge)))
        XCTAssertEqual(model.state.grants, [grant])
    }
}
