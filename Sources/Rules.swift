import Foundation

/// Everything a rule may need. Detection happens in `SystemCheck`; rules only
/// decide what to show and which safe action to offer.
struct RuleContext {
    let profile: DeviceProfile
    let interactive: Bool
    let notificationCPU: Double
    let acSleepMinutes: Int
    let loginItems: [String]
    let memFreePct: Double
    let swapUsedMB: Double
    let diskFreeGB: Double
    let diskFreePct: Double
    let windowServerCPU: Double
    let kernelTaskCPU: Double
    let batteryHealthPct: Double
    let batteryCondition: String
    let batteryCycles: Int
    let brewServices: [String]
    let helpers: [HelperService]
    let heavyApps: [HeavyApp]
}

struct HeavyApp {
    let name: String
    let bundleID: String
    let cpu: Double
    let pid: Int32
}

struct HelperService {
    let label: String
    let friendlyName: String
    let admin: Bool
    let plistPath: String?
}

enum Rules {
    private static let severityOrder: [Severity: Int] = [.high: 0, .medium: 1, .low: 2]

    static func build(_ context: RuleContext) -> [FixSuggestion] {
        var fixes: [FixSuggestion] = []

        // Hardware — no automatic fix.
        if context.profile.hasBattery,
           context.batteryCondition == "Service Recommended",
           context.batteryHealthPct < 80 {
            fixes.append(FixSuggestion(
                id: "battery",
                title: "Battery needs service",
                detail: String(
                    format: "Health is %.1f%% after %d cycles and macOS reports \"%@\". This is hardware: no software fix exists. Book a replacement; until then keep the Mac plugged in and close heavy background apps.",
                    context.batteryHealthPct, context.batteryCycles, context.batteryCondition
                ),
                severity: context.batteryHealthPct < 60 ? .high : .medium,
                command: "",
                admin: false,
                value: "\(Int(context.batteryHealthPct))% health"
            ))
        }

        if context.diskFreePct < 10 || context.diskFreeGB < 15 {
            fixes.append(FixSuggestion(
                id: "disk",
                title: "Free up disk space",
                detail: "Only \(Int(context.diskFreeGB)) GB (\(Int(context.diskFreePct))% of the disk) is free. macOS slows down when the startup disk fills. Move large files off the Mac or empty the Bin; MacPulse never deletes files for you.",
                severity: context.diskFreePct < 5 ? .high : .medium,
                command: "",
                admin: false,
                value: "\(Int(context.diskFreeGB)) GB free"
            ))
        }

        // Memory pressure.
        if context.memFreePct < 10 || context.swapUsedMB > 1024 {
            fixes.append(FixSuggestion(
                id: "purge",
                title: "Flush inactive memory",
                detail: "Only \(Int(context.memFreePct))% of memory is free and swap is at \(Int(context.swapUsedMB)) MB. Purging inactive caches frees RAM immediately; apps reload data afterwards.",
                severity: context.swapUsedMB > 2048 ? .high : .medium,
                command: "purge",
                admin: true,
                value: "\(Int(context.memFreePct))% free"
            ))
        }

        // Stuck Notification Center.
        if context.notificationCPU > 5 {
            fixes.append(FixSuggestion(
                id: "notifications",
                title: "Reset Notification Center",
                detail: "NotificationCenter and usernoted are using \(Int(context.notificationCPU))% CPU. Restarting them clears the stuck loop; no notification history is lost.",
                severity: .medium,
                command: "killall NotificationCenter 2>/dev/null; killall usernoted 2>/dev/null; true",
                admin: false,
                value: "\(Int(context.notificationCPU))% CPU"
            ))
        }

        // Short sleep timer (laptops and desktops both honour it on AC).
        if context.acSleepMinutes > 0 && context.acSleepMinutes <= 5 {
            fixes.append(FixSuggestion(
                id: "sleep",
                title: "Extend the sleep timer",
                detail: "Your Mac sleeps after \(context.acSleepMinutes) minute\(context.acSleepMinutes == 1 ? "" : "s") on power, which interrupts downloads, builds and backups. This sets 30 minutes on AC, 10 minutes for the display and disk.",
                severity: .high,
                command: "pmset -c sleep 30 displaysleep 10 disksleep 10",
                admin: true,
                value: "\(context.acSleepMinutes) min",
                undoCommand: "pmset -c sleep \(context.acSleepMinutes) displaysleep 10 disksleep 10"
            ))
        }

        // Thermal throttling.
        if context.kernelTaskCPU > 25 {
            fixes.append(FixSuggestion(
                id: "thermal",
                title: "The Mac is thermally throttling",
                detail: "kernel_task is at \(Int(context.kernelTaskCPU))%, which is how macOS slows the CPU when it gets hot. Close heavy apps, keep vents clear, and avoid charging in a hot room. This is advice only — nothing is changed automatically.",
                severity: context.kernelTaskCPU > 50 ? .high : .medium,
                command: "",
                admin: false,
                value: "\(Int(context.kernelTaskCPU))% kernel_task"
            ))
        }

        // WindowServer — usually animation in a background tab.
        if context.windowServerCPU > 60 {
            fixes.append(FixSuggestion(
                id: "windowserver",
                title: "Close animated tabs",
                detail: "WindowServer is at \(Int(context.windowServerCPU))% CPU. A background tab with video, an animated page or a live canvas is usually the cause. Close or pause it to recover that CPU.",
                severity: .medium,
                command: "",
                admin: false,
                value: "\(Int(context.windowServerCPU))% CPU"
            ))
        }

        // One app eating a core.
        for app in context.heavyApps.prefix(2) {
            fixes.append(FixSuggestion(
                id: "quit-\(app.bundleID)",
                title: "Quit \(app.name)",
                detail: "\(app.name) is using \(Int(app.cpu))% of one CPU core. Quitting frees CPU, battery and memory. MacPulse sends a normal Quit request, never a force kill, so save your work first.",
                severity: app.cpu > 150 ? .medium : .low,
                command: "",
                admin: false,
                value: "\(Int(app.cpu))% CPU",
                nativeAction: "quit",
                nativeTarget: String(app.pid)
            ))
        }

        // Homebrew services that start at login.
        for service in context.brewServices.prefix(3) {
            let safeName = service.replacingOccurrences(
                of: "[^A-Za-z0-9._-]",
                with: "",
                options: .regularExpression
            )
            guard !safeName.isEmpty, safeName == service else { continue }
            fixes.append(FixSuggestion(
                id: "brew-\(service)",
                title: "Stop the \(service) service",
                detail: "Homebrew service \"\(service)\" is running in the background. Stop it if you do not need it right now; Docker, databases and dev servers are common culprits. Start it again any time with brew services start \(service).",
                severity: .low,
                command: "brew services stop \(service)",
                admin: false,
                value: "running",
                undoCommand: "brew services start \(service)"
            ))
        }

        // Third-party background helpers (VPN, VM, tablet, game launcher).
        for helper in context.helpers.prefix(3) {
            guard helper.label.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else { continue }
            let domain = helper.admin ? "system" : "gui/$(id -u)"
            let command = "launchctl bootout \(domain)/\(helper.label) 2>/dev/null; launchctl disable \(domain)/\(helper.label) 2>/dev/null; true"
            var undo: String?
            if let plist = helper.plistPath, plist.range(of: "^/Library/|^" + NSHomeDirectory(), options: .regularExpression) != nil {
                undo = "launchctl enable \(domain)/\(helper.label); launchctl bootstrap \(domain) \"\(plist)\""
            }
            fixes.append(FixSuggestion(
                id: "helper-\(helper.label)",
                title: "Disable \(helper.friendlyName) background helper",
                detail: "\(helper.label) starts automatically and stays loaded. Disable it if you do not need \(helper.friendlyName) today; it stays installed and can be re-enabled from Settings or with Undo.",
                severity: .low,
                command: command,
                admin: helper.admin,
                value: "loaded",
                undoCommand: undo
            ))
        }

        // Login items (only read in interactive scans).
        for name in context.loginItems where !name.isEmpty {
            guard name.range(of: "^[A-Za-z0-9 ._-]+$", options: .regularExpression) != nil else { continue }
            let escaped = name
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            fixes.append(FixSuggestion(
                id: "login-\(name)",
                title: "Remove login item: \(name)",
                detail: "\(name) opens automatically every time you log in. Remove it if you do not need it at startup. macOS may ask once for permission to control Login Items.",
                severity: .low,
                command: "/usr/bin/osascript -e 'tell application \"System Events\" to delete login item \"\(escaped)\"'",
                admin: false,
                value: "login item"
            ))
        }

        return fixes.sorted { (severityOrder[$0.severity] ?? 3) < (severityOrder[$1.severity] ?? 3) }
    }
}
