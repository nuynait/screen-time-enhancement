import Foundation

enum EmergencyUnlockDuration: String, CaseIterable, Identifiable {
    case fifteenMinutes, thirtyMinutes, oneHour, twoHours, fourHours, today

    var id: String { rawValue }
    var title: String {
        switch self {
        case .fifteenMinutes: "15 minutes"
        case .thirtyMinutes: "30 minutes"
        case .oneHour: "1 hour"
        case .twoHours: "2 hours"
        case .fourHours: "4 hours"
        case .today: "Rest of today"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .fifteenMinutes: 900
        case .thirtyMinutes: 1800
        case .oneHour: 3600
        case .twoHours: 7200
        case .fourHours: 14400
        case .today: nil
        }
    }
}

/// An in-memory choice window, created only after verifying the emergency code.
/// Capture midnight once: leaving the picker open must never turn today into tomorrow.
struct EmergencyUnlockOptions: Equatable, Identifiable {
    let id = UUID()
    let verifiedAt: Date
    let dayEndsAt: Date

    init(now: Date = Date(), calendar: Calendar = .current) throws {
        guard let end = calendar.dateInterval(of: .day, for: now)?.end else {
            throw EmergencyUnlockError.expired
        }
        verifiedAt = now
        dayEndsAt = end
    }

    func available(at now: Date) -> [EmergencyUnlockDuration] {
        guard now >= verifiedAt, now < dayEndsAt else { return [] }
        return EmergencyUnlockDuration.allCases.filter { duration in
            if duration == .fifteenMinutes { return true }
            if let seconds = duration.seconds { return now.addingTimeInterval(seconds) <= dayEndsAt }
            return dayEndsAt.timeIntervalSince(now) >= 900
        }
    }

    func expiry(for duration: EmergencyUnlockDuration, at now: Date) throws -> Date {
        let choices = available(at: now)
        guard !choices.isEmpty else { throw EmergencyUnlockError.expired }
        guard choices.contains(duration) else { throw EmergencyUnlockError.unavailableDuration }
        return duration.seconds.map { now.addingTimeInterval($0) } ?? dayEndsAt
    }
}

enum EmergencyUnlockError: LocalizedError {
    case expired, unavailableDuration

    var errorDescription: String? {
        switch self {
        case .expired: "This bypass has expired. Go back and enter the passcode again."
        case .unavailableDuration: "There is less time left today. Choose another window."
        }
    }
}
