import Foundation

/// Pure policy for the optional low-score alert. A notification is sent only
/// when the score crosses the threshold from above, so a Mac that stays low does
/// not send one every day.
enum ScoreAlert {
    static func shouldNotify(
        previousScore: Int?,
        currentScore: Int,
        threshold: Int,
        enabled: Bool
    ) -> Bool {
        guard enabled, let previous = previousScore else { return false }
        return previous >= threshold && currentScore < threshold
    }

    static func title() -> String {
        L10n.t("notifications.title")
    }

    static func body(previousScore: Int, currentScore: Int, threshold: Int) -> String {
        if previousScore >= threshold {
            return L10n.t("notifications.body", previousScore, currentScore)
        }
        return L10n.t("notifications.bodyBelow", currentScore, threshold)
    }
}
