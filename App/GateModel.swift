import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI
import UserNotifications

struct AppRow: Identifiable {
    let id: UUID
    let token: ApplicationToken?
    let demoName: String?
}

struct ChallengeSession: Identifiable {
    let id = UUID()
    let app: AppRow?
    let problem: MultiplicationChallenge
    let unlockDuration: UnlockDuration
}

@MainActor
final class GateModel: ObservableObject {
    @Published var state = GateState()
    @Published var authorized = false
    @Published var isAuthorizing = false
    @Published var errorMessage: String?
    @Published var challenge: ChallengeSession?
    @Published var selection = FamilyActivitySelection()
    let isDemo: Bool
    private var service: GateService?
    private let demoApps = [
        AppRow(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, token: nil, demoName: "Rednote"),
        AppRow(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, token: nil, demoName: "Bilibili")
    ]

    init() {
        #if DEBUG
        isDemo = ProcessInfo.processInfo.arguments.contains("--demo")
        #else
        isDemo = false
        #endif
        if isDemo {
            authorized = true
            if ProcessInfo.processInfo.arguments.contains("--challenge") { beginChallenge(for: demoApps[0]) }
        } else {
            do { service = try GateService() }
            catch { errorMessage = error.localizedDescription }
            refresh()
        }
    }

    var apps: [AppRow] {
        isDemo ? demoApps : state.apps.map { .init(id: $0.id, token: $0.token, demoName: nil) }
    }

    var unlockDuration: UnlockDuration { state.unlockDuration }

    func setUnlockDuration(_ duration: UnlockDuration) {
        do {
            if isDemo { state.unlockDuration = duration }
            else {
                guard let service else { throw GateError.missingAppGroup }
                state = try service.setUnlockDuration(duration)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func refresh() {
        if isDemo {
            state.grants.removeAll { !$0.isActive(at: Date()) }
            return
        }
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        do {
            if let service {
                state = authorized ? try service.reconcile() : try service.read()
                selection.applicationTokens = Set(state.apps.map(\.token))
                if authorized, challenge == nil, let pending = state.pendingChallenge,
                   let app = apps.first(where: { $0.id == pending.appID }) {
                    try service.clearPendingChallenge()
                    if grant(for: app.id) == nil { beginChallenge(for: app) }
                }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func authorize() async {
        isAuthorizing = true
        defer { isAuthorizing = false }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            if service == nil { service = try GateService() }
            refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func allowNotifications() async {
        do {
            let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            if !allowed { errorMessage = "Notifications are off. You can enable them in Settings, or open Gate from your Home Screen after preparing a calculation." }
        } catch { errorMessage = error.localizedDescription }
    }

    func saveSelection(_ newSelection: FamilyActivitySelection) -> Bool {
        do {
            guard let service else { throw GateError.missingAppGroup }
            state = try service.select(newSelection)
            selection = newSelection
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func beginChallenge(for app: AppRow?) {
        guard app == nil || authorized else {
            errorMessage = GateError.authorizationRequired.localizedDescription
            return
        }
        let problem: MultiplicationChallenge
        #if DEBUG
        problem = ProcessInfo.processInfo.arguments.contains("--uitesting")
            ? .init(left: 47, right: 63) : .random()
        #else
        problem = .random()
        #endif
        // Freeze the displayed duration so the accepted answer grants exactly what this screen offered.
        challenge = ChallengeSession(app: app, problem: problem, unlockDuration: unlockDuration)
    }

    func grant(for appID: UUID) -> UnlockGrant? {
        state.grants.first { $0.appID == appID && $0.isActive(at: Date()) }
    }

    func submit(_ answer: String, for session: ChallengeSession) throws -> Date? {
        guard challenge?.id == session.id, session.problem.accepts(answer) else { return nil }
        guard let app = session.app else { return Date() }
        if isDemo {
            let grant = UnlockGrant(appID: app.id, duration: session.unlockDuration)
            state.grants.removeAll { $0.appID == app.id }
            state.grants.append(grant)
            return grant.expiresAt
        }
        guard let service else { throw GateError.missingAppGroup }
        state = try service.unlock(appID: app.id, duration: session.unlockDuration)
        return grant(for: app.id)?.expiresAt
    }

    func lock(_ app: AppRow) {
        do {
            if isDemo { state.grants.removeAll { $0.appID == app.id } }
            else if let service { state = try service.lock(appID: app.id) }
        } catch { errorMessage = error.localizedDescription }
    }
}
