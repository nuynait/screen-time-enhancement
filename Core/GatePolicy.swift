import Foundation

struct MultiplicationChallenge: Equatable {
    let left: Int
    let right: Int

    static func random() -> Self {
        Self(left: Int.random(in: 10...99), right: Int.random(in: 10...99))
    }

    func accepts(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }),
              let answer = Int(trimmed) else { return false }
        return answer == left * right
    }
}

struct UnlockGrant: Codable, Equatable, Identifiable {
    static let duration: TimeInterval = 15 * 60
    static let activityPrefix = "gate.unlock."
    let id: UUID
    let appID: UUID
    let issuedAt: Date
    let expiresAt: Date

    init(appID: UUID, now: Date = Date(), id: UUID = UUID()) {
        self.id = id
        self.appID = appID
        issuedAt = now
        expiresAt = now.addingTimeInterval(Self.duration)
    }

    var activityName: String { Self.activityPrefix + id.uuidString }

    func isActive(at now: Date) -> Bool {
        // Moving the clock behind the grant must not produce an unlimited pass.
        now >= issuedAt && now < expiresAt
    }
}

struct UnlockSchedule {
    let start: DateComponents
    let end: DateComponents

    init(grant: UnlockGrant) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        // DeviceActivity truncates to whole seconds and requires a minimum 15-minute interval.
        // Round the end up so the scheduled block never precedes the promised grant expiry.
        let first = Date(timeIntervalSince1970: floor(grant.issuedAt.timeIntervalSince1970) - 1)
        let last = Date(timeIntervalSince1970: ceil(grant.expiresAt.timeIntervalSince1970))
        var start = calendar.dateComponents(components, from: first)
        var end = calendar.dateComponents(components, from: last)
        start.timeZone = calendar.timeZone
        end.timeZone = calendar.timeZone
        self.start = start
        self.end = end
    }
}

enum GrantPolicy {
    static func active(_ grants: [UnlockGrant], selectedIDs: Set<UUID>, at now: Date) -> [UnlockGrant] {
        grants.filter { selectedIDs.contains($0.appID) && $0.isActive(at: now) }
    }

    static func blockedIDs(selectedIDs: Set<UUID>, grants: [UnlockGrant], at now: Date) -> Set<UUID> {
        selectedIDs.subtracting(active(grants, selectedIDs: selectedIDs, at: now).map(\.appID))
    }
}
