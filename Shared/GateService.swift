import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class GateService {
    private let storage: LockedJSONStore<GateState>
    private let settings = ManagedSettingsStore(named: .init("calculation-gate"))
    private let center = DeviceActivityCenter()

    init() throws {
        guard let identifier = Bundle.main.object(forInfoDictionaryKey: "GateAppGroup") as? String,
              let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            throw GateError.missingAppGroup
        }
        storage = LockedJSONStore(directory: directory, initialValue: { GateState() })
    }

    func read() throws -> GateState { try storage.read() }

    func setUnlockDuration(_ duration: UnlockDuration) throws -> GateState {
        // A preference edit must not reschedule or revoke any existing grant.
        try storage.update { $0.unlockDuration = duration }
    }

    func setCalculationSettings(_ preferences: CalculationSettings) throws -> GateState {
        try storage.update { $0.calculationSettings = preferences }
    }

    @discardableResult
    func reconcile(at now: Date = Date()) throws -> GateState {
        let state = try mutate(at: now) { _ in }
        // DeviceActivity may synchronously invoke an extension. Never call it while holding our file lock.
        let retained = Set(state.grants.map(\.activityName))
        let stale = center.activities.filter {
            $0.rawValue.hasPrefix(UnlockGrant.activityPrefix) && !retained.contains($0.rawValue)
        }
        if !stale.isEmpty { center.stopMonitoring(stale) }
        return state
    }

    func select(_ selection: FamilyActivitySelection) throws -> GateState {
        try requireAuthorization()
        guard selection.categoryTokens.isEmpty, selection.webDomainTokens.isEmpty else {
            throw GateError.individualAppsOnly
        }
        guard selection.applicationTokens.count <= 12 else { throw GateError.tooManyApps }
        _ = try mutate { state in
            let kept = state.apps.filter { selection.applicationTokens.contains($0.token) }
            let known = Set(kept.map(\.token))
            state.apps = kept + selection.applicationTokens.subtracting(known).map { GuardedApp(id: UUID(), token: $0) }
        }
        return try reconcile()
    }

    func requestChallenge(for token: ApplicationToken) throws {
        _ = try mutate { state in
            guard let app = state.apps.first(where: { $0.token == token }) else { throw GateError.appRemoved }
            state.pendingChallenge = PendingChallenge(appID: app.id, createdAt: Date())
        }
    }

    func clearPendingChallenge() throws {
        _ = try storage.update { $0.pendingChallenge = nil }
    }

    func unlock(_ grant: UnlockGrant) throws -> GateState {
        let now = grant.issuedAt
        let appID = grant.appID
        try requireAuthorization()
        _ = try reconcile(at: now)
        let name = DeviceActivityName(grant.activityName)
        let bounds = UnlockSchedule(grant: grant)
        let schedule = DeviceActivitySchedule(intervalStart: bounds.start, intervalEnd: bounds.end, repeats: false)

        // Register the system expiry BEFORE removing a shield. A failed registration grants no access.
        try center.startMonitoring(name, during: schedule)
        do {
            return try mutate(at: now) { state in
                guard state.apps.contains(where: { $0.id == appID }) else { throw GateError.appRemoved }
                guard !state.grants.contains(where: { $0.appID == appID }) else { throw GateError.alreadyUnlocked }
                state.grants.append(grant)
                state.pendingChallenge = nil
            }
        } catch {
            center.stopMonitoring([name])
            throw error
        }
    }

    func lock(appID: UUID) throws -> GateState {
        _ = try mutate { $0.grants.removeAll { $0.appID == appID } }
        return try reconcile()
    }

    /// A late callback from an old grant must never revoke a newer window for the same app.
    func intervalEnded(activityName: String, now: Date = Date()) throws {
        guard activityName.hasPrefix(UnlockGrant.activityPrefix) else { return }
        _ = try mutate(at: now) { _ in }
    }

    private func requireAuthorization() throws {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { throw GateError.authorizationRequired }
    }

    private func mutate(at now: Date = Date(), _ change: (inout GateState) throws -> Void) throws -> GateState {
        try storage.update({ state in
            state.removeExpiredGrants(at: now)
            try change(&state)
            state.removeExpiredGrants(at: now)
        }, afterSave: { state in
            let blocked = GrantPolicy.blockedIDs(selectedIDs: Set(state.apps.map(\.id)), grants: state.grants, at: now)
            let tokens = Set(state.apps.filter { blocked.contains($0.id) }.map(\.token))
            self.settings.shield.applications = tokens.isEmpty ? nil : tokens
        })
    }
}
