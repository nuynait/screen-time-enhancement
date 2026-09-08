import FamilyControls
import Foundation
import ManagedSettings

struct GuardedApp: Codable, Identifiable, Equatable {
    let id: UUID
    let token: ApplicationToken
}

struct PendingChallenge: Codable {
    let appID: UUID
    let createdAt: Date
}

struct GateState: Codable {
    var version = 1
    var apps: [GuardedApp] = []
    var grants: [UnlockGrant] = []
    var pendingChallenge: PendingChallenge?

    mutating func removeExpiredGrants(at now: Date) {
        grants = GrantPolicy.active(grants, selectedIDs: Set(apps.map(\.id)), at: now)
        if let pending = pendingChallenge,
           !apps.contains(where: { $0.id == pending.appID }) ||
            now.timeIntervalSince(pending.createdAt) > 10 * 60 || now < pending.createdAt {
            pendingChallenge = nil
        }
    }
}

enum GateError: LocalizedError {
    case missingAppGroup, authorizationRequired, individualAppsOnly, tooManyApps, appRemoved, alreadyUnlocked

    var errorDescription: String? {
        switch self {
        case .missingAppGroup: return "Shared storage is unavailable. Check that all four targets have the same App Group in Signing & Capabilities."
        case .authorizationRequired: return "Allow Screen Time access before protecting or unlocking apps."
        case .individualAppsOnly: return "Choose individual apps inside each category. Whole categories and websites aren't supported yet."
        case .tooManyApps: return "Choose up to 12 apps so each one can have its own unlock timer."
        case .appRemoved: return "This app is no longer in your protected list. Choose it again to continue."
        case .alreadyUnlocked: return "This app already has an active 15-minute window."
        }
    }
}
