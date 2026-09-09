import XCTest
@testable import GateCore

final class EmergencyPasscodeTests: XCTestCase {
    func testRequiresExactlyFourASCIIDigitsAndMatchingConfirmation() throws {
        let storage = TestPasscodeStorage()
        let passcode = EmergencyPasscode(storage: storage)
        XCTAssertFalse(try passcode.isConfigured)
        XCTAssertThrowsError(try passcode.verify("1234"))
        for invalid in ["", "123", "12345", "１２３４", "١٢٣٤", " 1234", "12a4", "-123", "12.4"] {
            XCTAssertFalse(EmergencyPasscode.isValid(invalid))
            XCTAssertThrowsError(try passcode.set(invalid, confirmation: invalid, current: nil))
        }
        XCTAssertThrowsError(try passcode.set("0123", confirmation: "0124", current: nil))
        XCTAssertNil(storage.value)
        try passcode.set("0123", confirmation: "0123", current: nil)
        XCTAssertTrue(try passcode.isConfigured)
        try passcode.verify("0123")
        XCTAssertThrowsError(try passcode.verify("123"))
    }

    func testChangingAndRemovingRequireTheCurrentCodeAndPersistAcrossInstances() throws {
        let storage = TestPasscodeStorage()
        let passcode = EmergencyPasscode(storage: storage)
        try passcode.set("0123", confirmation: "0123", current: nil)
        for wrong in [nil, "9999", ""] as [String?] {
            XCTAssertThrowsError(try passcode.set("4567", confirmation: "4567", current: wrong))
            XCTAssertThrowsError(try passcode.remove(current: wrong ?? ""))
            try passcode.verify("0123")
        }
        try passcode.set("4567", confirmation: "4567", current: "0123")
        let reopened = EmergencyPasscode(storage: storage)
        try reopened.verify("4567")
        XCTAssertThrowsError(try reopened.verify("0123"))
        XCTAssertThrowsError(try reopened.remove(current: "0123"))
        try reopened.remove(current: "4567")
        XCTAssertFalse(try passcode.isConfigured)
        XCTAssertThrowsError(try reopened.verify("4567"))
    }

    func testStorageFailuresAndCorruptCredentialsNeverEnableBypassOrOverwriteTheCode() throws {
        let storage = TestPasscodeStorage()
        let passcode = EmergencyPasscode(storage: storage)
        try passcode.set("0123", confirmation: "0123", current: nil)
        storage.failWrites = true
        XCTAssertThrowsError(try passcode.set("4567", confirmation: "4567", current: "0123"))
        XCTAssertThrowsError(try passcode.remove(current: "0123"))
        try passcode.verify("0123")
        storage.failReads = true
        XCTAssertThrowsError(try passcode.verify("0123"))
        XCTAssertThrowsError(try passcode.set("4567", confirmation: "4567", current: "0123"))
        storage.failReads = false
        storage.failWrites = false
        storage.value = "corrupt"
        XCTAssertThrowsError(try passcode.isConfigured)
        XCTAssertThrowsError(try passcode.verify("0123"))
        XCTAssertThrowsError(try passcode.set("4567", confirmation: "4567", current: nil))
        XCTAssertEqual(storage.value, "corrupt")
    }
}

private final class TestPasscodeStorage: EmergencyPasscodeStorage {
    var value: String?
    var failReads = false
    var failWrites = false
    func read() throws -> String? {
        if failReads { throw EmergencyPasscodeError.unreadable }
        return value
    }
    func write(_ passcode: String?) throws {
        if failWrites { throw EmergencyPasscodeError.unreadable }
        value = passcode
    }
}
