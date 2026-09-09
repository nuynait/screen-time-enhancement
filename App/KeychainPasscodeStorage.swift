import Foundation
import Security

struct KeychainPasscodeStorage: EmergencyPasscodeStorage {
    let service: String

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "emergency-bypass",
         kSecAttrSynchronizable as String: false]
    }

    func read() throws -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        try check(status)
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw EmergencyPasscodeError.unreadable
        }
        return value
    }

    func write(_ passcode: String?) throws {
        guard let passcode else {
            let status = SecItemDelete(query as CFDictionary)
            if status != errSecItemNotFound { try check(status) }
            return
        }
        // Keep the secret local to this device and available only while it is unlocked.
        let attributes: [String: Any] = [
            kSecValueData as String: Data(passcode.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            try check(SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil))
        } else {
            try check(status)
        }
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Couldn't access the saved passcode. Try again while your iPhone is unlocked."
            ])
        }
    }
}

#if DEBUG
final class PreviewPasscodeStorage: EmergencyPasscodeStorage {
    private var passcode: String?
    func read() -> String? { passcode }
    func write(_ passcode: String?) { self.passcode = passcode }
}
#endif
