import ManagedSettings
import os

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            do {
                try GateService().requestChallenge(for: application)
                GateHandoff.respond(completionHandler)
            } catch {
                Logger(subsystem: "screen-time-enhancement", category: "shield").error("Challenge handoff failed: \(error.localizedDescription)")
                completionHandler(.close)
            }
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }
}
