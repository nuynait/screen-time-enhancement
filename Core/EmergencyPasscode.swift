import Foundation

protocol EmergencyPasscodeStorage {
    func read() throws -> String?
    func write(_ passcode: String?) throws
}

enum EmergencyPasscodeError: LocalizedError {
    case invalidFormat, mismatch, incorrect, notConfigured, unreadable

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Enter exactly four digits."
        case .mismatch: return "Passcodes don't match. Try again."
        case .incorrect: return "Incorrect passcode. Try again."
        case .notConfigured: return "Emergency bypass hasn't been set up."
        case .unreadable: return "Couldn't read the saved passcode. Your calculation is still available."
        }
    }
}

/// Only the app needs this credential; extensions continue to share grant state through LockedJSONStore.
struct EmergencyPasscode {
    let storage: any EmergencyPasscodeStorage

    static func isValid(_ value: String) -> Bool {
        value.utf8.count == 4 && value.utf8.allSatisfy { (48...57).contains($0) }
    }

    var isConfigured: Bool { get throws { try savedPasscode() != nil } }

    func verify(_ candidate: String) throws {
        guard Self.isValid(candidate) else { throw EmergencyPasscodeError.invalidFormat }
        guard let saved = try savedPasscode() else { throw EmergencyPasscodeError.notConfigured }
        guard candidate == saved else { throw EmergencyPasscodeError.incorrect }
    }

    func set(_ passcode: String, confirmation: String, current: String?) throws {
        guard Self.isValid(passcode) else { throw EmergencyPasscodeError.invalidFormat }
        guard passcode == confirmation else { throw EmergencyPasscodeError.mismatch }
        // Recheck on the final write, not just when the editing screen opens.
        if try isConfigured { try verify(current ?? "") }
        try storage.write(passcode)
    }

    func remove(current: String) throws {
        try verify(current)
        try storage.write(nil)
    }

    private func savedPasscode() throws -> String? {
        let saved = try storage.read()
        if let saved, !Self.isValid(saved) { throw EmergencyPasscodeError.unreadable }
        return saved
    }
}
