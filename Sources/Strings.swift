import Foundation

/// The single catalogue for user-facing copy. English ships today; adding a
/// language means adding one dictionary instead of hunting through every view.
///
/// Keys are stable and flat (`history.title`, `onboarding.privacy.body`). A
/// missing key returns the key itself so a blank label can never ship silently.
enum L10n {
    static let defaultLanguage = "en"

    /// User or test override language. When nil, matches the best available language
    /// from Locale.preferredLanguages, falling back to defaultLanguage ("en").
    static var overrideLanguage: String? = nil

    /// Active language code ("en", "de", "fr", "es", "ja").
    static var currentLanguage: String {
        if let override = overrideLanguage, catalogue[override] != nil {
            return override
        }
        for preferred in Locale.preferredLanguages {
            let prefix = String(preferred.prefix(2)).lowercased()
            if catalogue[prefix] != nil {
                return prefix
            }
        }
        return defaultLanguage
    }

    private static let catalogue: [String: [String: String]] = [
        "en": englishStrings,
        "de": germanStrings,
        "fr": frenchStrings,
        "es": spanishStrings,
        "ja": japaneseStrings
    ]

    static let englishStrings: [String: String] = [
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

            // Language selector
            "settings.language.title": "Language",
            "settings.language.label": "Display language:",
            "settings.language.system": "System Default",
            "settings.language.detail": "Choose a specific language or use your macOS system language.",

            "common.clear": "Clear",
            "common.restore": "Restore",
            "common.restoreAll": "Restore All",
            "common.undo": "Undo",
            "dashboard.activity.undone": "UNDONE",
            "dashboard.declinedCount": "%d declined",
            "dashboard.noProcessData": "No process data available",
            "dashboard.nothingToFix": "Nothing to fix",
            "dashboard.nothingToFix.detail": "Every automated check passed on this run.",
            "dashboard.pts": "pts",
            "dashboard.scoreLabel": "score",
            "dashboard.showCommand": "Show command",
            "fix.adminBadge": "Asks for admin password",
            "fix.approve": "Approve",
            "fix.decline": "Decline",
            "fix.dismiss": "Dismiss",
            "fix.quitApp": "Quit App",
            "fix.quitBadge": "Sends a normal Quit request",
            "fix.running": "Running…",
            "fix.undoBadge": "Can be undone",
            "metric.battery.accessories": "%d accessories",
            "metric.battery.cycles": "%d cycles · %@ · %d%%",
            "metric.battery.cyclesWithPeriph": "%d cycles · %@",
            "metric.battery.desktopPower": "Desktop Mac — running on power",
            "metric.battery.health": "%d%% health",
            "metric.battery.noBattery": "No battery",
            "metric.battery.title": "Battery",
            "metric.cpu.title": "CPU Load",
            "metric.memory.caption": "%.0f GB total · %.1f GB compressed · %.0f MB swap",
            "metric.memory.title": "Memory",
            "metric.memory.value": "%d%% free",
            "metric.sleep.acCaption": "Applies while on the power adapter",
            "metric.sleep.assertionsActive": "%d sleep assertions active",
            "metric.sleep.caffeinateBlocked": "Sleep blocked by caffeinate",
            "metric.sleep.never": "Never",
            "metric.sleep.title": "Auto-sleep (AC)",
            "metric.startup.caption": "%d launch agents installed",
            "metric.startup.title": "Startup",
            "metric.startup.value": "%d login items",
            "metric.storage.caption": "%d%% of %d GB available",
            "metric.storage.title": "Storage",
            "metric.storage.value": "%d GB free",
            "metric.thermals.caption": "kernel_task — CPU throttling indicator",
            "metric.thermals.title": "Thermals",
            "metric.windowserver.caption": "Compositing / display overhead",
            "metric.windowserver.title": "WindowServer",
            "settings.advanced.preview.detail": "Expands the exact shell command on all fix cards without needing to click Preview.",
            "settings.advanced.preview.title": "Always show command preview",
            "settings.advanced.reset.button": "Reset Everything",
            "settings.advanced.reset.detail": "Clears cached check results, recent activity history, and restores default preferences.",
            "settings.advanced.reset.title": "Reset All Data",
            "settings.advanced.title": "Advanced & Privacy",
            "settings.declined.empty": "No suggestions have been declined.",
            "settings.declined.restore": "Restore",
            "settings.declined.restoreAll": "Restore All",
            "settings.declined.title": "Declined Suggestions",
            "settings.exclusions.count": "%d excluded",
            "settings.exclusions.detail": "Turn off recommendations you do not wish to see. Excluded rules will not produce suggestions in interactive or background scans.",
            "settings.exclusions.title": "Rule Exclusions",
            "settings.history.detail": "MacPulse keeps the last %d scans locally so it can show a score trend and what changed since yesterday.",
            "settings.menubarAndAlerts.title": "Menu Bar & Alerts",
            "settings.rule.backup.detail": "Explains high CPU while Time Machine copies changes",
            "settings.rule.backup.name": "Backup activity",
            "settings.rule.battery.detail": "Advice for failing or degraded laptop batteries",
            "settings.rule.battery.name": "Battery health",
            "settings.rule.brew.detail": "Suggestions to stop idle running background Homebrew services",
            "settings.rule.brew.name": "Homebrew services",
            "settings.rule.disk.detail": "Warnings when free disk space drops below 10% or 15 GB",
            "settings.rule.disk.name": "Disk space",
            "settings.rule.dns.detail": "Offer to flush the DNS cache when mDNSResponder is busy",
            "settings.rule.dns.name": "DNS responder",
            "settings.rule.helper.detail": "Suggestions to disable third-party startup helpers and daemons",
            "settings.rule.helper.name": "Background helpers",
            "settings.rule.mdm.detail": "Information when this Mac is enrolled in mobile device management",
            "settings.rule.mdm.name": "Managed Mac",
            "settings.rule.notifications.detail": "Restart suggestions when NotificationCenter consumes CPU",
            "settings.rule.notifications.name": "Notification Center",
            "settings.rule.peripheral-battery.detail": "Warnings when connected Bluetooth or HID device battery drops below 20%",
            "settings.rule.peripheral-battery.name": "Accessory battery",
            "settings.rule.purge.detail": "Reclaim inactive RAM when free memory is under 10% or swap exceeds 1 GB",
            "settings.rule.purge.name": "Memory purge",
            "settings.rule.quit.detail": "Suggestions to gracefully quit GUI apps using over 60% CPU",
            "settings.rule.quit.name": "Heavy apps",
            "settings.rule.sleep-caffeinate.detail": "Offer to stop caffeinate processes holding wake-locks",
            "settings.rule.sleep-caffeinate.name": "Keep-awake assertions",
            "settings.rule.sleep.detail": "Offer to increase sleep timer on AC power from 1–5 minutes",
            "settings.rule.sleep.name": "Sleep timer",
            "settings.rule.smb.detail": "Advice when a mounted SMB share is using CPU",
            "settings.rule.smb.name": "Network shares",
            "settings.rule.spotlight.detail": "Explains high CPU while Spotlight indexes new files",
            "settings.rule.spotlight.name": "Spotlight indexing",
            "settings.rule.thermal.detail": "Advice when kernel_task throttles the CPU due to heat",
            "settings.rule.thermal.name": "Thermal throttling",
            "settings.rule.timemachine.detail": "Advice for a missing backup disk or a backup older than a week, and start-backup suggestions",
            "settings.rule.timemachine.name": "Time Machine",
            "settings.rule.windowserver.detail": "Advice to close animated background tabs causing high CPU",
            "settings.rule.windowserver.name": "WindowServer animation",
            "settings.schedule.detail": "MacPulse uses a native per-user LaunchAgent (com.macpulse.daily) to run a silent check once a day without keeping an app open in the dock.",
            "settings.schedule.runsDailyAt": "Runs daily at %@",
            "settings.schedule.time": "Scheduled Time:",
            "settings.schedule.title": "Daily Background Check",
            "settings.title": "MacPulse Settings",

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

            // Power assertions and peripheral battery rules
            "rule.sleep_caffeinate.title": "Sleep prevented by caffeinate",
            "rule.sleep_caffeinate.detail": "A background caffeinate process (PID %d) is keeping this Mac awake. Stop it to restore normal system sleep.",
            "rule.sleep_caffeinate.value": "PID %d",
            "rule.peripheral.title": "%@ battery low (%d%%)",
            "rule.peripheral.detail": "%@ is at %d%% battery. Charge or replace batteries soon to prevent disconnection.",
            "rule.peripheral.value": "%d%%"
    ]

    /// Looks up `key` in the current language, falling back to English, then to the key.
    /// Extra arguments are applied with `String(format:)`.
    static func t(_ key: String, _ arguments: CVarArg...) -> String {
        let lang = currentLanguage
        let template = catalogue[lang]?[key] ?? catalogue[defaultLanguage]?[key] ?? key
        guard !arguments.isEmpty else { return template }
        return String(format: template, arguments: arguments)
    }

    static func has(_ key: String) -> Bool {
        catalogue[currentLanguage]?[key] != nil || catalogue[defaultLanguage]?[key] != nil
    }

    /// Every key in the default language, sorted.
    static var keys: [String] {
        (catalogue[defaultLanguage] ?? [:]).keys.sorted()
    }

    /// Active dictionary in the current resolved language.
    static var strings: [String: String] {
        catalogue[currentLanguage] ?? catalogue[defaultLanguage] ?? [:]
    }

    /// All supported language codes.
    static var supportedLanguages: [String] {
        Array(catalogue.keys).sorted()
    }
}
