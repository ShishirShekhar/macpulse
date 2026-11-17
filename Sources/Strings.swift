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

            // Dashboard
            "dashboard.systemHealth": "System health",
            "dashboard.recommendedFixes": "Recommended fixes",
            "dashboard.recentActivity": "Recent activity",
            "dashboard.topProcesses": "Top processes",
            "dashboard.checking": "Checking…",
            "dashboard.checkNow": "Check Now",
            "dashboard.dailyCheckOff": "Daily check off",
            "dashboard.dailyAt": "Daily at %@",
            "dashboard.upTime": "Up %@",
            "dashboard.checked": "Checked %@",
            "dashboard.scoreBreakdown.title": "Score Breakdown (starts at 100)",
            "dashboard.worthALook": "Worth a look",
            "dashboard.allClear": "All clear",
            "dashboard.allClear.detail": "All primary metrics are within normal ranges. MacPulse found no background issues.",

            // Updates (opt-in)
            "updates.title": "Software Updates",
            "updates.toggle": "Automatically check for updates",
            "updates.toggle.detail": "Periodically checks GitHub Releases for newer MacPulse versions. No personal info or diagnostics are sent.",
            "updates.checkNow": "Check for Updates",
            "updates.checking": "Checking for updates…",
            "updates.upToDate": "MacPulse is up to date (version %@).",
            "updates.available": "MacPulse %@ is available.",
            "updates.download": "View Release",
            "updates.failed": "Could not check for updates. Check your internet connection.",

            // Empty and error states
            "empty.title": "No scan yet",
            "empty.body": "Run a check to see this Mac's score, metrics and recommended fixes.",
            "empty.errorTitle": "Some readings were unavailable",
            "empty.errorBody": "MacPulse finished the scan but could not collect every value. Running the check again usually fixes it.",
            "loading.title": "Scanning this Mac…",
            "loading.body": "CPU, memory, disk, battery, startup items and top processes",

            // Rule catalogue
            "rule.battery.title": "Battery needs service",
            "rule.battery.detail": "Health is %.1f%% after %d cycles and macOS reports \"%@\". This is hardware: no software fix exists. Book a replacement; until then keep the Mac plugged in and close heavy background apps.",
            "rule.battery.value": "%d%% health",
            "rule.disk.title": "Free up disk space",
            "rule.disk.detail": "Only %d GB (%d%% of the disk) is free. macOS slows down when the startup disk fills. Move large files off the Mac or empty the Bin; MacPulse never deletes files for you.",
            "rule.disk.value": "%d GB free",
            "rule.purge.title": "Flush inactive memory",
            "rule.purge.detail": "Only %d%% of memory is free and swap is at %d MB. Purging inactive caches frees RAM immediately; apps reload data afterwards.",
            "rule.purge.value": "%d%% free",
            "rule.notifications.title": "Reset Notification Center",
            "rule.notifications.detail": "NotificationCenter and usernoted are using %d%% CPU. Restarting them clears the stuck loop; no notification history is lost.",
            "rule.notifications.value": "%d%% CPU",
            "rule.sleep.title": "Extend the sleep timer",
            "rule.sleep.detail": "Your Mac sleeps after %d minute%@ on power, which interrupts downloads, builds and backups. This sets 30 minutes on AC, 10 minutes for the display and disk.",
            "rule.sleep.value": "%d min",
            "rule.thermal.title": "The Mac is thermally throttling",
            "rule.thermal.detail": "kernel_task is at %d%%, which is how macOS slows the CPU when it gets hot. Close heavy apps, keep vents clear, and avoid charging in a hot room. This is advice only — nothing is changed automatically.",
            "rule.thermal.value": "%d%% kernel_task",
            "rule.windowserver.title": "Close animated tabs",
            "rule.windowserver.detail": "WindowServer is at %d%% CPU. A background tab with video, an animated page or a live canvas is usually the cause. Close or pause it to recover that CPU.",
            "rule.windowserver.value": "%d%% CPU",
            "rule.quit.title": "Quit %@",
            "rule.quit.detail": "%@ is using %d%% of one CPU core. Quitting frees CPU, battery and memory. MacPulse sends a normal Quit request, never a force kill, so save your work first.",
            "rule.quit.value": "%d%% CPU",
            "rule.brew.title": "Stop the %@ service",
            "rule.brew.detail": "Homebrew service \"%@\" is running in the background. Stop it if you do not need it right now; Docker, databases and dev servers are common culprits. Start it again any time with brew services start %@.",
            "rule.brew.value": "running",
            "rule.helper.title": "Disable %@ background helper",
            "rule.helper.detail": "%@ starts automatically and stays loaded. Disable it if you do not need %@ today; it stays installed and can be re-enabled from Settings or with Undo.",
            "rule.helper.value": "loaded",
            "rule.login.title": "Remove login item: %@",
            "rule.login.detail": "%@ opens automatically every time you log in. Remove it if you do not need it at startup. macOS may ask once for permission to control Login Items.",
            "rule.login.value": "login item",

            // Time Machine, indexing, DNS, SMB and MDM rules
            "rule.timemachine.none.title": "Set up Time Machine backups",
            "rule.timemachine.none.detail": "No backup disk is configured. A local backup protects your files if the drive fails; open System Settings → General → Time Machine to choose a disk. MacPulse will not change backup settings for you.",
            "rule.timemachine.none.value": "no backup disk",
            "rule.timemachine.stale.title": "Back up now",
            "rule.timemachine.stale.detail": "The last Time Machine backup finished %d days ago. Start a backup now; the first one can take a while, and later ones only copy changes.",
            "rule.timemachine.stale.value": "%d days ago",
            "rule.backup.title": "Time Machine is backing up",
            "rule.backup.detail": "backupd is using %d%% CPU while Time Machine copies changes. This is normal while a backup runs and settles when it finishes. Do not disconnect the backup disk.",
            "rule.backup.value": "%d%% CPU",
            "rule.spotlight.title": "Spotlight is indexing",
            "rule.spotlight.detail": "Spotlight indexing (mds and mdworker) is using %d%% CPU. It usually settles after new files, an OS update or a new drive is indexed. Leave the Mac plugged in and awake; indexing pauses when you need the CPU.",
            "rule.spotlight.value": "%d%% CPU",
            "rule.dns.title": "Flush the DNS cache",
            "rule.dns.detail": "The DNS responder is using %d%% CPU. Flushing the local DNS cache clears stuck lookups and is safe; websites reconnect immediately.",
            "rule.dns.value": "%d%% CPU",
            "rule.smb.title": "Check the network share",
            "rule.smb.detail": "An SMB share is mounted (%@) and smbd is using %d%% CPU. Disconnect shares you are not using from the Finder sidebar, or copy files locally instead of working over the network.",
            "rule.smb.value": "%d%% CPU",
            "rule.mdm.title": "This Mac is managed",
            "rule.mdm.detail": "An organization manages this Mac through mobile device management. Some settings are controlled remotely and cannot be changed here. MacPulse never disables MDM, profiles or security settings.",
            "rule.mdm.value": "managed",
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
