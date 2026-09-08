import SwiftUI
import UserNotifications

final class GateAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .gateChallengeRequested, object: nil)
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let gateChallengeRequested = Notification.Name("gateChallengeRequested")
}

@main
struct GateApp: App {
    @UIApplicationDelegateAdaptor(GateAppDelegate.self) private var delegate
    @StateObject private var model = GateModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView(model: model)
                .tint(GateTheme.blue)
                .task { await model.refreshNotifications() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        model.returnToForeground()
                        model.refresh()
                        Task { await model.refreshNotifications() }
                    } else {
                        model.leaveForeground()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .gateChallengeRequested)) { _ in model.refresh() }
                .onOpenURL { url in
                    if url.scheme == "calculationgate" { model.refresh() }
                }
        }
    }
}
