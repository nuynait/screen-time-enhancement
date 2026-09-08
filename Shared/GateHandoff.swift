import Foundation
import ManagedSettings
import UserNotifications

enum GateHandoff {
    static var opensAppDirectly: Bool {
        #if SCREEN_TIME_CAN_OPEN_APP
        if #available(iOS 26.5, *) { return true }
        #endif
        return false
    }

    static func respond(_ completion: @escaping (ShieldActionResponse) -> Void) {
        #if SCREEN_TIME_CAN_OPEN_APP
        if #available(iOS 26.5, *) {
            completion(.openParentalControlsApp)
            return
        }
        #endif
        let content = UNMutableNotificationContent()
        content.title = "Your calculation is ready"
        content.body = "Tap to open Gate and solve your calculation."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "gate.pending-challenge", content: content, trigger: nil)
        // If notifications are disabled, the shield also explains how to open Gate manually.
        let response = ShieldCompletion(completion)
        UNUserNotificationCenter.current().add(request) { _ in response.close() }
    }
}

// Apple's shield completion predates Sendable, but is intended for asynchronous responses.
// This immutable bridge is used once by the notification submission callback.
private final class ShieldCompletion: @unchecked Sendable {
    private let handler: (ShieldActionResponse) -> Void
    init(_ handler: @escaping (ShieldActionResponse) -> Void) { self.handler = handler }
    func close() { handler(.close) }
}
