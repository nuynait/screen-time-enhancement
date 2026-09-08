import DeviceActivity
import XCTest

final class GateStateTests: XCTestCase {
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
        XCTAssertEqual(state.grants.count, 1)
        XCTAssertEqual(state.grants[0].expiresAt.timeIntervalSinceReferenceDate, 10900)
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
