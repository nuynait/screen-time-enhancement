import Security
import XCTest
@testable import Gate

final class KeychainPasscodeTests: XCTestCase {
    func testKeychainPersistenceProtectionUpdateAndRemoval() throws {
        // A unique test-only service never reads or changes the installed app's credential.
        let service = "gate.tests." + UUID().uuidString
        let storage = KeychainPasscodeStorage(service: service)
        defer { try? storage.write(nil) }
        let passcode = EmergencyPasscode(storage: storage)
        XCTAssertFalse(try passcode.isConfigured)
        try passcode.set("0123", confirmation: "0123", current: nil)
        let reopened = EmergencyPasscode(storage: KeychainPasscodeStorage(service: service))
        try reopened.verify("0123")
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: "emergency-bypass",
                                    kSecReturnAttributes as String: true]
        var result: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &result), errSecSuccess)
        let attributes = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        XCTAssertNotEqual(attributes[kSecAttrSynchronizable as String] as? Bool, true)
        try reopened.set("4567", confirmation: "4567", current: "0123")
        XCTAssertThrowsError(try passcode.verify("0123"))
        try passcode.verify("4567")
        try passcode.remove(current: "4567")
        XCTAssertFalse(try reopened.isConfigured)
    }
}
