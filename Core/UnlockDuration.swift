import Foundation

enum UnlockDuration: Int, CaseIterable, Codable, Identifiable {
    case oneMinute = 1
    case threeMinutes = 3
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case sixtyMinutes = 60

    static let defaultValue = Self.fifteenMinutes
    var id: Int { rawValue }
    var seconds: TimeInterval { TimeInterval(rawValue * 60) }
    var title: String { rawValue == 1 ? "1 minute" : "\(rawValue) minutes" }

    init(from decoder: Decoder) throws {
        let minutes = try decoder.singleValueContainer().decode(Int.self)
        // An unsupported setting must not make the whole shared state unreadable.
        self = Self(rawValue: minutes) ?? .defaultValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
