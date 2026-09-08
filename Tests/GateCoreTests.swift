import Foundation
import XCTest
@testable import GateCore

final class GateCoreTests: XCTestCase {
    func testAnswerMustBeTheFullIntegerProduct() {
        let challenge = MultiplicationChallenge(left: 47, right: 63)
        XCTAssertTrue(challenge.accepts("2961"))
        XCTAssertTrue(challenge.accepts(" 2961\n"))
        for answer in ["", "2960", "2961.0", "2961 trailing", "2,961", "-2961", "+2961", "２９６１", "999999999999999999999999999"] {
            XCTAssertFalse(challenge.accepts(answer), answer)
        }
    }

    func testEveryGeneratedOperandHasTwoDigits() {
        for _ in 0..<1000 {
            let problem = MultiplicationChallenge.random()
            XCTAssertTrue((10...99).contains(problem.left))
            XCTAssertTrue((10...99).contains(problem.right))
            XCTAssertTrue(problem.accepts(String(problem.left * problem.right)))
        }
    }

    func testUnlockIsPerAppAndExpiresExactlyAtFifteenMinutes() {
        let a = UUID(), b = UUID()
        let now = Date(timeIntervalSince1970: 10_000)
        let grant = UnlockGrant(appID: a, now: now)
        XCTAssertEqual(grant.expiresAt.timeIntervalSince(now), 900)
        XCTAssertEqual(GrantPolicy.blockedIDs(selectedIDs: [a, b], grants: [grant], at: now), [b])
        XCTAssertEqual(GrantPolicy.blockedIDs(selectedIDs: [a, b], grants: [grant], at: now.addingTimeInterval(899.999)), [b])
        XCTAssertEqual(GrantPolicy.blockedIDs(selectedIDs: [a, b], grants: [grant], at: now.addingTimeInterval(900)), [a, b])
    }

    func testClockRollbackDoesNotExtendGrant() {
        let now = Date(timeIntervalSince1970: 10_000)
        let grant = UnlockGrant(appID: UUID(), now: now)
        XCTAssertFalse(grant.isActive(at: now.addingTimeInterval(-1)))
    }

    func testSchedulePreservesAbsoluteExpiryAcrossMidnightAndDST() throws {
        let parser = ISO8601DateFormatter()
        let dates = ["2026-09-08T23:59:59Z", "2026-03-08T06:59:59Z", "2026-11-01T05:59:59Z"]
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = TimeZone(identifier: "America/Toronto")!
        for input in dates {
            let now = try XCTUnwrap(parser.date(from: input)).addingTimeInterval(0.456)
            let grant = UnlockGrant(appID: UUID(), now: now)
            let bounds = UnlockSchedule(grant: grant)
            let start = try XCTUnwrap(localCalendar.date(from: bounds.start))
            let end = try XCTUnwrap(localCalendar.date(from: bounds.end))
            XCTAssertLessThanOrEqual(start, now)
            XCTAssertGreaterThanOrEqual(end.timeIntervalSince(start), 900)
            XCTAssertGreaterThanOrEqual(end, grant.expiresAt)
            XCTAssertLessThan(end.timeIntervalSince(grant.expiresAt), 1)
        }
    }

    func testRemovingAnAppDiscardsItsGrant() {
        let now = Date()
        let a = UUID(), b = UUID()
        XCTAssertTrue(GrantPolicy.active([UnlockGrant(appID: a, now: now)], selectedIDs: [b], at: now).isEmpty)
    }

    func testOldExpiryCannotInvalidateNewWindow() {
        let now = Date(timeIntervalSince1970: 10_000)
        let app = UUID()
        let old = UnlockGrant(appID: app, now: now)
        let new = UnlockGrant(appID: app, now: now.addingTimeInterval(901))
        XCTAssertNotEqual(old.activityName, new.activityName)
        XCTAssertEqual(GrantPolicy.active([old, new], selectedIDs: [app], at: now.addingTimeInterval(902)), [new])
    }

    func testPersistedGrantSurvivesRelaunch() throws {
        let now = Date()
        let grant = UnlockGrant(appID: UUID(), now: now)
        let restored = try JSONDecoder().decode(UnlockGrant.self, from: JSONEncoder().encode(grant))
        XCTAssertEqual(restored, grant)
        XCTAssertTrue(restored.isActive(at: now.addingTimeInterval(60)))
    }

    func testIndependentStoresSerializeConcurrentReadModifyWrites() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        struct Counter: Codable { var count = 0 }
        let store = LockedJSONStore(directory: directory, initialValue: { Counter() })
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            let other = LockedJSONStore(directory: directory, initialValue: { Counter() })
            do { try other.update { $0.count += 1 } }
            catch { XCTFail("Concurrent transaction failed: \(error)") }
        }
        XCTAssertEqual(try store.read().count, 100)
    }

    func testCorruptionDoesNotResetOrOverwriteState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("state.json")
        let corrupt = Data("not json".utf8)
        try corrupt.write(to: url)
        let store = LockedJSONStore(directory: directory, initialValue: { [String]() })
        XCTAssertThrowsError(try store.read())
        XCTAssertThrowsError(try store.update { $0.append("lost settings") })
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }

    func testFailedTransactionLeavesPreviousStateIntact() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LockedJSONStore(directory: directory, initialValue: { ["protected"] })
        enum Failure: Error { case rejected }
        try store.update { $0.append("also protected") }
        XCTAssertThrowsError(try store.update { value in
            value.removeAll()
            throw Failure.rejected
        })
        XCTAssertEqual(try store.read(), ["protected", "also protected"])
    }
}
