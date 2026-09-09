import DeviceActivity
import XCTest

final class GateStateTests: XCTestCase {
    func testEmergencySchedulesResolveAndStateReloadKeepsExactExpiry() throws {
        let now = Date()
        let options = try EmergencyUnlockOptions(now: now)
        for duration in options.available(at: now) {
            let grant = UnlockGrant(appID: UUID(), expiresAt: try options.expiry(for: duration, at: now), now: now)
            var state = GateState()
            state.grants = [grant]
            let loaded = try JSONDecoder().decode(GateState.self, from: JSONEncoder().encode(state))
            XCTAssertEqual(loaded.grants, [grant])
            let bounds = UnlockSchedule(grant: loaded.grants[0])
            let schedule = DeviceActivitySchedule(intervalStart: bounds.start, intervalEnd: bounds.end, repeats: false)
            let interval = try XCTUnwrap(schedule.nextInterval, duration.title)
            XCTAssertLessThanOrEqual(interval.start, now)
            XCTAssertGreaterThanOrEqual(interval.end, grant.expiresAt)
            XCTAssertLessThan(interval.end.timeIntervalSince(grant.expiresAt), 1)
        }
    }

    func testDeviceActivityResolvesEachDurationToItsUpcomingExpiry() throws {
        let now = Date()
        for duration in UnlockDuration.allCases {
            let grant = UnlockGrant(appID: UUID(), duration: duration, now: now)
            let bounds = UnlockSchedule(grant: grant)
            let schedule = DeviceActivitySchedule(intervalStart: bounds.start, intervalEnd: bounds.end, repeats: false)
            let interval = try XCTUnwrap(schedule.nextInterval, duration.title)
            XCTAssertLessThanOrEqual(interval.start, now, duration.title)
            XCTAssertGreaterThanOrEqual(interval.duration, 15 * 60, duration.title)
            XCTAssertGreaterThanOrEqual(interval.end, grant.expiresAt, duration.title)
            XCTAssertLessThan(interval.end.timeIntervalSince(grant.expiresAt), 1, duration.title)
        }
    }

    func testOldStateDefaultsToFifteenMinutesWithoutLosingGrants() throws {
        let legacy = Data("""
        {"version":1,"apps":[],"grants":[{
          "id":"11111111-1111-1111-1111-111111111111",
          "appID":"22222222-2222-2222-2222-222222222222",
          "issuedAt":10000,"expiresAt":10900
        }]}
        """.utf8)
        let state = try JSONDecoder().decode(GateState.self, from: legacy)
        XCTAssertEqual(state.unlockDuration, .fifteenMinutes)
        XCTAssertEqual(state.calculationSettings, .defaultValue)
        XCTAssertEqual(state.grants.count, 1)
        XCTAssertEqual(state.grants[0].expiresAt.timeIntervalSinceReferenceDate, 10900)
    }

    func testCalculationPreferencesSurviveReloadAndPreserveOtherState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let grant = UnlockGrant(appID: UUID(), duration: .fiveMinutes)
        let pending = PendingChallenge(appID: UUID(), createdAt: Date())
        let store = LockedJSONStore(directory: directory, initialValue: { GateState() })
        try store.update {
            $0.grants = [grant]
            $0.pendingChallenge = pending
            $0.unlockDuration = .thirtyMinutes
        }
        for operation in CalculationOperation.allCases {
            for first in CalculationDigits.allCases {
                for second in CalculationDigits.allCases {
                    let preferences = CalculationSettings(firstDigits: first, secondDigits: second, operation: operation)
                    try store.update { $0.calculationSettings = preferences }
                    let loaded = try LockedJSONStore(directory: directory, initialValue: { GateState() }).read()
                    XCTAssertEqual(loaded.calculationSettings, preferences)
                    XCTAssertEqual(loaded.grants, [grant])
                    XCTAssertEqual(loaded.unlockDuration, .thirtyMinutes)
                    XCTAssertEqual(loaded.pendingChallenge?.appID, pending.appID)
                    XCTAssertEqual(loaded.pendingChallenge?.createdAt, pending.createdAt)
                }
            }
        }
    }

    func testPartialAndUnknownCalculationPreferencesUseDefaultsButBadTypesFail() throws {
        let partial = Data("""
        {"version":1,"apps":[],"grants":[],"firstNumberDigits":3,"calculationOperation":"future"}
        """.utf8)
        let state = try JSONDecoder().decode(GateState.self, from: partial)
        XCTAssertEqual(state.calculationSettings, .init(firstDigits: .three))
        let malformed = Data("""
        {"version":1,"apps":[],"grants":[],"firstNumberDigits":"three"}
        """.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(GateState.self, from: malformed))
    }

    func testChangingAndReloadingDurationDoesNotChangeExistingGrant() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let existing = UnlockGrant(appID: UUID(), duration: .fiveMinutes)
        let store = LockedJSONStore(directory: directory, initialValue: { GateState() })
        try store.update { state in
            state.grants = [existing]
            state.unlockDuration = .thirtyMinutes
        }
        let reopened = LockedJSONStore(directory: directory, initialValue: { GateState() })
        let loaded = try reopened.read()
        XCTAssertEqual(loaded.unlockDuration, .thirtyMinutes)
        XCTAssertEqual(loaded.grants, [existing])
        try reopened.update { $0.unlockDuration = .oneMinute }
        XCTAssertEqual(try store.read().unlockDuration, .oneMinute)
        XCTAssertEqual(try store.read().grants, [existing])
    }
}
