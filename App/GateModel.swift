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
    enum Destination {
        case app(AppRow), practice, settings
    }

    let id = UUID()
    let destination: Destination
    let problem: CalculationChallenge
    let calculationSettings: CalculationSettings
    let unlockDuration: UnlockDuration
    let wasRefreshed: Bool

    var app: AppRow? {
        if case .app(let app) = destination { return app }
        return nil
    }

    var isSettingsGate: Bool {
        if case .settings = destination { return true }
        return false
    }
}

@MainActor
final class GateModel: ObservableObject {
    @Published var state = GateState()
    @Published var authorized = false
    @Published var isAuthorizing = false
    @Published var errorMessage: String?
    @Published var challenge: ChallengeSession?
    @Published var selection = FamilyActivitySelection()
    @Published private(set) var notificationAuthorization: UNAuthorizationStatus?
    @Published private(set) var isUpdatingNotifications = false
    let isDemo: Bool
    private let testsNotifications: Bool
    private var service: GateService?
    private var challengeToRefresh: UUID?
    private var completedChallengeID: UUID?
    private let demoApps = [
        AppRow(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, token: nil, demoName: "Rednote"),
        AppRow(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, token: nil, demoName: "Bilibili")
    ]

    init() {
        #if DEBUG
        isDemo = ProcessInfo.processInfo.arguments.contains("--demo")
        testsNotifications = isDemo && ProcessInfo.processInfo.arguments.contains("--uitesting")
            && ProcessInfo.processInfo.arguments.contains("--test-notifications")
        #else
        isDemo = false
        testsNotifications = false
        #endif
        if isDemo {
            authorized = true
            if !testsNotifications { notificationAuthorization = .authorized }
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
    var calculationSettings: CalculationSettings { state.calculationSettings }

    func setCalculationSettings(_ preferences: CalculationSettings) {
        do {
            if isDemo { state.calculationSettings = preferences }
            else {
                guard let service else { throw GateError.missingAppGroup }
                state = try service.setCalculationSettings(preferences)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    var usesNotificationHandoff: Bool { testsNotifications || !GateHandoff.opensAppDirectly }
    var canManageNotifications: Bool { !isDemo || testsNotifications }

    var needsNotificationPermission: Bool {
        usesNotificationHandoff && (notificationAuthorization == .notDetermined || notificationAuthorization == .denied)
    }

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
            await refreshNotifications()
        } catch { errorMessage = error.localizedDescription }
    }

    func refreshNotifications() async {
        await updateNotifications(requestIfNeeded: authorized, openSettings: false)
    }

    func allowNotifications() async {
        await updateNotifications(requestIfNeeded: true, openSettings: true)
    }

    private func updateNotifications(requestIfNeeded: Bool, openSettings: Bool) async {
        guard usesNotificationHandoff, !isUpdatingNotifications, canManageNotifications else { return }
        // Scene activation can race the first prompt or a button tap. Only one request may run.
        isUpdatingNotifications = true
        defer { isUpdatingNotifications = false }
        let center = UNUserNotificationCenter.current()
        notificationAuthorization = await center.notificationSettings().authorizationStatus
        if notificationAuthorization == .notDetermined {
            guard requestIfNeeded else { return }
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch { errorMessage = error.localizedDescription }
            notificationAuthorization = await center.notificationSettings().authorizationStatus
            // Declining the first prompt must not immediately send someone to Settings.
            return
        }
        guard openSettings else { return }
        // iOS never repeats a denied prompt. This URL opens this app's notification page.
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        let opened = await UIApplication.shared.open(url)
        if !opened, let fallback = URL(string: UIApplication.openSettingsURLString) {
            let openedFallback = await UIApplication.shared.open(fallback)
            if !openedFallback { errorMessage = "Couldn't open iPhone Settings. Open Settings and find Gate to change notification permissions." }
        }
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
        beginChallenge(destination: app.map { .app($0) } ?? .practice)
    }

    func beginSettingsChallenge() {
        beginChallenge(destination: .settings)
    }

    private func beginChallenge(destination: ChallengeSession.Destination) {
        if case .app = destination, !authorized {
            errorMessage = GateError.authorizationRequired.localizedDescription
            return
        }
        let problem: CalculationChallenge
        #if DEBUG
        problem = ProcessInfo.processInfo.arguments.contains("--uitesting")
            ? calculationSettings.example : .random(settings: calculationSettings)
        #else
        problem = .random(settings: calculationSettings)
        #endif
        // Freeze the displayed duration so the accepted answer grants exactly what this screen offered.
        completedChallengeID = nil
        challenge = ChallengeSession(destination: destination, problem: problem,
                                     calculationSettings: calculationSettings, unlockDuration: unlockDuration,
                                     wasRefreshed: false)
    }

    func leaveForeground() {
        guard let session = challenge, completedChallengeID != session.id else {
            challengeToRefresh = nil
            return
        }
        // Also invalidate during an inactive transition (for example Control Center).
        challengeToRefresh = session.id
    }

    func returnToForeground() {
        defer { challengeToRefresh = nil }
        guard let session = challenge, challengeToRefresh == session.id,
              completedChallengeID != session.id else { return }
        challenge = ChallengeSession(destination: session.destination,
                                     problem: .replacing(session.problem, settings: session.calculationSettings),
                                     calculationSettings: session.calculationSettings,
                                     unlockDuration: session.unlockDuration, wasRefreshed: true)
    }

    func grant(for appID: UUID) -> UnlockGrant? {
        state.grants.first { $0.appID == appID && $0.isActive(at: Date()) }
    }

    func submit(_ answer: String, for session: ChallengeSession) throws -> Date? {
        guard challenge?.id == session.id, challengeToRefresh != session.id,
              completedChallengeID != session.id, session.problem.accepts(answer) else { return nil }
        // Practice and Settings access never create, extend, or revoke app grants.
        guard let app = session.app else {
            completedChallengeID = session.id
            return Date()
        }
        if isDemo {
            let grant = UnlockGrant(appID: app.id, duration: session.unlockDuration)
            state.grants.removeAll { $0.appID == app.id }
            state.grants.append(grant)
            completedChallengeID = session.id
            return grant.expiresAt
        }
        guard let service else { throw GateError.missingAppGroup }
        state = try service.unlock(appID: app.id, duration: session.unlockDuration)
        completedChallengeID = session.id
        return grant(for: app.id)?.expiresAt
    }

    func lock(_ app: AppRow) {
        do {
            if isDemo { state.grants.removeAll { $0.appID == app.id } }
            else if let service { state = try service.lock(appID: app.id) }
        } catch { errorMessage = error.localizedDescription }
    }
}
