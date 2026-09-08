import DeviceActivity
import os

final class ActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        do {
            try GateService().intervalEnded(activityName: activity.rawValue)
        } catch {
            Logger(subsystem: "screen-time-enhancement", category: "expiry").error("Could not reapply shields: \(error.localizedDescription)")
        }
    }
}
