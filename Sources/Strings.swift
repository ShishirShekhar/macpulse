import Foundation

/// The single catalogue for user-facing copy. English ships today; adding a
/// language means adding one dictionary instead of hunting through every view.
///
/// Keys are stable and flat (`history.title`, `onboarding.privacy.body`). A
/// missing key returns the key itself so a blank label can never ship silently.
enum L10n {
    static let defaultLanguage = "en"

    private static let catalogue: [String: [String: String]] = [
        "en": [
            // Shared
            "common.done": "Done",
            "common.cancel": "Cancel",
            "common.checkNow": "Check Now",
            "common.settings": "Settings",
            "common.on": "On",
            "common.off": "Off",

            // Onboarding
            "onboarding.title": "Welcome to MacPulse",
            "onboarding.subtitle": "A quick, private health check for your Mac. Everything runs on this Mac and nothing is uploaded.",
            "onboarding.reads.title": "What MacPulse reads",
            "onboarding.reads.body": "CPU load, memory pressure, disk space, battery health, startup items, background helpers and the busiest processes. It also reads your login items so it can suggest ones you may not need.",
            "onboarding.privacy.title": "What it never does",
            "onboarding.privacy.body": "No accounts, no analytics, no identifiers and no network calls. MacPulse never changes anything unless you approve a specific fix, and it never deletes your files.",
            "onboarding.permissions.title": "Permissions you may see",
            "onboarding.permissions.body": "macOS may ask for Automation access to read login items. An administrator password is requested only for the exact fix you approve. You can decline either prompt and the rest of the app still works.",
            "onboarding.schedule.title": "Daily background check",
            "onboarding.schedule.body": "MacPulse can run one silent check a day through a per-user LaunchAgent. It writes a local JSON result and never opens a window.",
            "onboarding.schedule.toggle": "Run a daily check at %@",
            "onboarding.start": "Start using MacPulse",
            "onboarding.later": "Not now",
            "onboarding.again": "Show the welcome tour again",

            // History
            "history.title": "Health trend",
            "history.subtitle": "Last %d checks, newest first",
            "history.empty": "Run a few checks over the next days to see your score trend here.",
            "history.sinceYesterday": "What changed since yesterday",
            "history.sinceLastCheck": "What changed since the last check",
            "history.scoreUp": "Score up %d points",
            "history.scoreDown": "Score down %d points",
            "history.scoreSame": "Score unchanged",
            "history.newFixes": "New: %@",
            "history.resolvedFixes": "Cleared: %@",
            "history.noChange": "No changes in score or recommendations.",
            "history.clear": "Clear history",
            "history.count": "%d saved checks",

            // Menu bar
            "menubar.toggle": "Show the score in the menu bar",
            "menubar.toggle.detail": "Adds a small MacPulse item with the latest score and quick actions.",
            "menubar.open": "Open MacPulse",
            "menubar.noScan": "No scan yet",
            "menubar.score": "Score %d — %@",

            // Notifications
            "notifications.toggle": "Notify me when the score drops",
            "notifications.toggle.detail": "Uses local macOS notifications only. Nothing leaves your Mac.",
            "notifications.threshold": "Alert below",
            "notifications.permissionDenied": "Notifications are turned off in System Settings, so MacPulse could not enable alerts.",
            "notifications.title": "MacPulse score dropped",
            "notifications.body": "Your score fell from %d to %d. Open MacPulse to see what changed.",
            "notifications.bodyBelow": "Your score is %d, below your alert threshold of %d. Open MacPulse to see what changed.",

            // Empty and error states
            "empty.title": "No scan yet",
            "empty.body": "Run a check to see this Mac's score, metrics and recommended fixes.",
            "empty.errorTitle": "Some readings were unavailable",
            "empty.errorBody": "MacPulse finished the scan but could not collect every value. Running the check again usually fixes it.",
            "loading.title": "Scanning this Mac…",
            "loading.body": "CPU, memory, disk, battery, startup items and top processes",
        ]
    ]

    /// Looks up `key` in the default language. Extra arguments are applied with
    /// `String(format:)`, so callers can keep one template per string.
    static func t(_ key: String, _ arguments: CVarArg...) -> String {
        let template = catalogue[defaultLanguage]?[key] ?? key
        guard !arguments.isEmpty else { return template }
        return String(format: template, arguments: arguments)
    }

    static func has(_ key: String) -> Bool {
        catalogue[defaultLanguage]?[key] != nil
    }

    /// Every key in the shipping language, sorted. Used by the tests to catch
    /// empty values and accidental duplicates in review.
    static var keys: [String] {
        (catalogue[defaultLanguage] ?? [:]).keys.sorted()
    }

    static var strings: [String: String] {
        catalogue[defaultLanguage] ?? [:]
    }
}
