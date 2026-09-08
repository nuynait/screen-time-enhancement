import Foundation
import Darwin

/// App and extensions are different processes: a serial queue alone cannot protect their writes.
final class LockedJSONStore<Value: Codable> {
    private let directory: URL
    private let initialValue: () -> Value

    init(directory: URL, initialValue: @escaping () -> Value) {
        self.directory = directory
        self.initialValue = initialValue
    }

    func read() throws -> Value {
        try withLock { try load() }
    }

    @discardableResult
    func update(_ change: (inout Value) throws -> Void,
                afterSave: (Value) -> Void = { _ in }) throws -> Value {
        try withLock {
            var value = try load()
            try change(&value)
            let data = try JSONEncoder().encode(value)
            try data.write(to: directory.appendingPathComponent("state.json"), options: .atomic)
            // Keep the system shield and persisted state in the same ordering across processes.
            afterSave(value)
            return value
        }
    }

    private func load() throws -> Value {
        let url = directory.appendingPathComponent("state.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return initialValue() }
        // A corrupt file is an error, never a reason to erase the user's selected apps.
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }

    private func withLock<T>(_ operation: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fd = open(directory.appendingPathComponent("state.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        defer { close(fd) }
        while flock(fd, LOCK_EX) != 0 {
            if errno != EINTR { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        }
        defer { flock(fd, LOCK_UN) }
        return try operation()
    }
}
