import XCTest
@testable import GateCore

final class EmergencyUnlockTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    func testChoicesStartAtFifteenMinutesAndTimedWindowsStartAtConfirmation() throws {
        let now = date("2026-09-09T12:00:00Z")
        let options = try EmergencyUnlockOptions(now: now, calendar: utc)
        XCTAssertEqual(options.available(at: now), EmergencyUnlockDuration.allCases)
        let confirmation = now.addingTimeInterval(137)
        for choice in EmergencyUnlockDuration.allCases {
            let expiry = try options.expiry(for: choice, at: confirmation)
            XCTAssertGreaterThanOrEqual(expiry.timeIntervalSince(confirmation), 900)
            XCTAssertLessThanOrEqual(expiry, options.dayEndsAt)
            if let seconds = choice.seconds {
                XCTAssertEqual(expiry.timeIntervalSince(confirmation), seconds)
            } else {
                XCTAssertEqual(expiry, date("2026-09-10T00:00:00Z"))
            }
        }
    }

    func testLateChoicesRespectMidnightAndTheFifteenMinuteMinimum() throws {
        let now = date("2026-09-09T23:40:00Z")
        let options = try EmergencyUnlockOptions(now: now, calendar: utc)
        XCTAssertEqual(options.available(at: now), [.fifteenMinutes, .today])
        XCTAssertThrowsError(try options.expiry(for: .thirtyMinutes, at: now))
        let boundary = date("2026-09-09T23:45:00Z")
        XCTAssertEqual(try options.expiry(for: .today, at: boundary).timeIntervalSince(boundary), 900)
        let late = boundary.addingTimeInterval(1)
        XCTAssertEqual(options.available(at: late), [.fifteenMinutes])
        XCTAssertThrowsError(try options.expiry(for: .today, at: late))
        XCTAssertEqual(try options.expiry(for: .fifteenMinutes, at: late), date("2026-09-10T00:00:01Z"))
    }

    func testPickerCannotRollIntoANewDayOrSurviveClockRollback() throws {
        let now = date("2026-09-09T12:00:00Z")
        let options = try EmergencyUnlockOptions(now: now, calendar: utc)
        for invalid in [now.addingTimeInterval(-1), options.dayEndsAt, options.dayEndsAt.addingTimeInterval(1)] {
            XCTAssertTrue(options.available(at: invalid).isEmpty)
            for choice in EmergencyUnlockDuration.allCases {
                XCTAssertThrowsError(try options.expiry(for: choice, at: invalid))
            }
        }
    }

    func testLocalMidnightAcrossDSTPersistsAsAnAbsoluteExpiry() throws {
        var calendar = utc
        for (start, end, hours) in [
            ("2026-03-08T05:00:00Z", "2026-03-09T04:00:00Z", 23),
            ("2026-11-01T04:00:00Z", "2026-11-02T05:00:00Z", 25)
        ] {
            calendar.timeZone = TimeZone(identifier: "America/New_York")!
            let now = date(start)
            let options = try EmergencyUnlockOptions(now: now, calendar: calendar)
            let expiry = try options.expiry(for: .today, at: now)
            XCTAssertEqual(expiry, date(end))
            XCTAssertEqual(expiry.timeIntervalSince(now), Double(hours * 3600))
            let grant = UnlockGrant(appID: UUID(), expiresAt: expiry, now: now)
            let loaded = try JSONDecoder().decode(UnlockGrant.self, from: JSONEncoder().encode(grant))
            XCTAssertEqual(loaded, grant)
            XCTAssertTrue(loaded.isActive(at: expiry.addingTimeInterval(-1)))
            XCTAssertFalse(loaded.isActive(at: expiry))
            let bounds = UnlockSchedule(grant: loaded)
            calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
            XCTAssertEqual(calendar.date(from: bounds.end), expiry)
        }
    }
}
