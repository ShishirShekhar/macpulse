import Foundation
import UserNotifications

/// Posts the optional local score alert. This is the only notification code in
/// the app: no push service, no remote identifiers, no network.
enum Notifications {
    static let enabledKey = "scoreNotificationsEnabled"
    static let thresholdKey = "scoreNotificationThreshold"
    static let defaultThreshold = 70

    /// Reads the user's stored preference. Used by both the UI and the headless
    /// daily check so behaviour is identical in both paths.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var threshold: Int {
        let stored = UserDefaults.standard.object(forKey: thresholdKey) as? Int
        return stored ?? defaultThreshold
    }

    /// Asks macOS for permission. The completion runs on the main queue.
    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("MacPulse notification permission failed: \(error)")
            }
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Called after every scan, including the headless one. Does nothing unless
    /// notifications are enabled and the score crossed the threshold.
    static func postIfNeeded(previous: CheckResult?, current: CheckResult) {
        guard isEnabled else { return }
        let previousScore = previous?.score
        guard ScoreAlert.shouldNotify(
            previousScore: previousScore,
            currentScore: current.score,
            threshold: threshold,
            enabled: true
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = ScoreAlert.title()
        content.body = ScoreAlert.body(
            previousScore: previousScore ?? threshold,
            currentScore: current.score,
            threshold: threshold
        )
        content.sound = .default

        let identifier = "macpulse-score-\(Int(current.date.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("MacPulse notification failed: \(error)")
            }
        }
    }

    /// Clears delivered MacPulse alerts when the user turns notifications off.
    static func clearDelivered() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
