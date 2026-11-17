import Foundation

/// Everything a rule may need. Detection happens in `SystemCheck`; rules only
/// decide what to show and which safe action to offer.
struct RuleContext {
    var profile: DeviceProfile
    var interactive: Bool
    var notificationCPU: Double
    var acSleepMinutes: Int
    var loginItems: [String]
    var memFreePct: Double
    var swapUsedMB: Double
    var diskFreeGB: Double
    var diskFreePct: Double
    var windowServerCPU: Double
    var kernelTaskCPU: Double
    var batteryHealthPct: Double
    var batteryCondition: String
    var batteryCycles: Int
    var brewServices: [String]
    var helpers: [HelperService]
    var heavyApps: [HeavyApp]

    // Phase 5 sources. Every field has a default so existing call sites and
    // fixtures keep compiling; a probe that cannot read a value leaves it at the
    // neutral value and no rule fires for it.
    var hasBackupDestination: Bool = true
    /// Days since the last completed Time Machine backup, when known.
    var lastBackupDays: Int? = nil
    var backupdCPU: Double = 0
    var spotlightCPU: Double = 0
    var dnsCPU: Double = 0
    var smbCPU: Double = 0
    var smbMounts: [String] = []
    var mdmEnrolled: Bool = false

    // Power assertions and peripheral battery sources
    var sleepAssertions: [SleepAssertion] = []
    var peripherals: [PeripheralBattery] = []
}

// MARK: - Rule Protocol

protocol DiagnosticRule {
    var id: String { get }
    func evaluate(context: RuleContext) -> [FixSuggestion]
}

// MARK: - Concrete Rules

struct BatteryHealthRule: DiagnosticRule {
    let id = "battery"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        guard context.profile.hasBattery,
              context.batteryCondition == "Service Recommended",
              context.batteryHealthPct < 80 else { return [] }

        return [FixSuggestion(
            id: "battery",
            title: L10n.t("rule.battery.title"),
            detail: L10n.t(
                "rule.battery.detail",
                context.batteryHealthPct, context.batteryCycles, context.batteryCondition
            ),
            severity: context.batteryHealthPct < 60 ? .high : .medium,
            command: "",
            admin: false,
            value: L10n.t("rule.battery.value", Int(context.batteryHealthPct))
        )]
    }
}

struct DiskSpaceRule: DiagnosticRule {
    let id = "disk"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        guard context.diskFreePct < 10 || context.diskFreeGB < 15 else { return [] }

        return [FixSuggestion(
            id: "disk",
            title: L10n.t("rule.disk.title"),
            detail: L10n.t(
                "rule.disk.detail",
                Int(context.diskFreeGB), Int(context.diskFreePct)
            ),
            severity: context.diskFreePct < 5 ? .high : .medium,
            command: "",
            admin: false,
            value: L10n.t("rule.disk.value", Int(context.diskFreeGB))
        )]
    }
}

struct MemoryPurgeRule: DiagnosticRule {
    let id = "purge"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        guard context.memFreePct < 10 || context.swapUsedMB > 1024 else { return [] }

        return [FixSuggestion(
            id: "purge",
            title: L10n.t("rule.purge.title"),
            detail: L10n.t(
                "rule.purge.detail",
                Int(context.memFreePct), Int(context.swapUsedMB)
            ),
            severity: context.swapUsedMB > 2048 ? .high : .medium,
            command: "purge",
            admin: true,
            value: L10n.t("rule.purge.value", Int(context.memFreePct))
        )]
    }
}

struct NotificationCenterRule: DiagnosticRule {
    let id = "notifications"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        guard context.notificationCPU > 5 else { return [] }

        return [FixSuggestion(
            id: "notifications",
            title: L10n.t("rule.notifications.title"),
            detail: L10n.t("rule.notifications.detail", Int(context.notificationCPU)),
            severity: .medium,
            command: "killall NotificationCenter 2>/dev/null; killall usernoted 2>/dev/null; true",
            admin: false,
            value: L10n.t("rule.notifications.value", Int(context.notificationCPU))
        )]
    }
}

struct SleepTimerRule: DiagnosticRule {
    let id = "sleep"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        guard context.acSleepMinutes > 0 && context.acSleepMinutes <= 5 else { return [] }

        return [FixSuggestion(
            id: "sleep",
            title: L10n.t("rule.sleep.title"),
            detail: L10n.t(
                "rule.sleep.detail",
                context.acSleepMinutes,
                context.acSleepMinutes == 1 ? "" : "s"
            ),
            severity: .high,
            command: "pmset -c sleep 30 displaysleep 10 disksleep 10",
            admin: true,
            value: L10n.t("rule.sleep.value", context.acSleepMinutes),
            undoCommand: "pmset -c sleep \(context.acSleepMinutes) displaysleep 10 disksleep 10"
        )]
    }
}

struct ThermalThrottlingRule: DiagnosticRule {
    let id = "thermal"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        guard context.kernelTaskCPU > 25 else { return [] }

        return [FixSuggestion(
            id: "thermal",
            title: L10n.t("rule.thermal.title"),
            detail: L10n.t("rule.thermal.detail", Int(context.kernelTaskCPU)),
            severity: context.kernelTaskCPU > 50 ? .high : .medium,
            command: "",
            admin: false,
            value: L10n.t("rule.thermal.value", Int(context.kernelTaskCPU))
        )]
    }
}

struct WindowServerRule: DiagnosticRule {
    let id = "windowserver"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        guard context.interactive && context.windowServerCPU > 60 else { return [] }

        return [FixSuggestion(
            id: "windowserver",
            title: L10n.t("rule.windowserver.title"),
            detail: L10n.t("rule.windowserver.detail", Int(context.windowServerCPU)),
            severity: .medium,
            command: "",
            admin: false,
            value: L10n.t("rule.windowserver.value", Int(context.windowServerCPU))
        )]
    }
}

struct TimeMachineRule: DiagnosticRule {
    let id = "timemachine"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        if !context.hasBackupDestination {
            return [FixSuggestion(
                id: "timemachine-none",
                title: L10n.t("rule.timemachine.none.title"),
                detail: L10n.t("rule.timemachine.none.detail"),
                severity: .low,
                command: "",
                admin: false,
                value: L10n.t("rule.timemachine.none.value")
            )]
        } else if let days = context.lastBackupDays, days >= 7 {
            return [FixSuggestion(
                id: "timemachine-stale",
                title: L10n.t("rule.timemachine.stale.title"),
                detail: L10n.t("rule.timemachine.stale.detail", days),
                severity: days >= 30 ? .medium : .low,
                command: "tmutil startbackup",
                admin: false,
                value: L10n.t("rule.timemachine.stale.value", days),
                undoCommand: "tmutil stopbackup"
            )]
        }
        return []
    }
}

struct BackupActivityRule: DiagnosticRule {
    let id = "backup"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        guard context.backupdCPU > 25 else { return [] }

        return [FixSuggestion(
            id: "backup",
            title: L10n.t("rule.backup.title"),
            detail: L10n.t("rule.backup.detail", Int(context.backupdCPU)),
            severity: context.backupdCPU > 60 ? .medium : .low,
            command: "",
            admin: false,
            value: L10n.t("rule.backup.value", Int(context.backupdCPU))
        )]
    }
}

struct SpotlightRule: DiagnosticRule {
    let id = "spotlight"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        guard context.spotlightCPU > 25 else { return [] }

        return [FixSuggestion(
            id: "spotlight",
            title: L10n.t("rule.spotlight.title"),
            detail: L10n.t("rule.spotlight.detail", Int(context.spotlightCPU)),
            severity: context.spotlightCPU > 60 ? .medium : .low,
            command: "",
            admin: false,
            value: L10n.t("rule.spotlight.value", Int(context.spotlightCPU))
        )]
    }
}

struct DNSResponderRule: DiagnosticRule {
    let id = "dns"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        guard context.dnsCPU > 10 else { return [] }

        return [FixSuggestion(
            id: "dns",
            title: L10n.t("rule.dns.title"),
            detail: L10n.t("rule.dns.detail", Int(context.dnsCPU)),
            severity: context.dnsCPU > 40 ? .medium : .low,
            command: "dscacheutil -flushcache; killall -HUP mDNSResponder 2>/dev/null; true",
            admin: true,
            value: L10n.t("rule.dns.value", Int(context.dnsCPU))
        )]
    }
}

struct SMBSharesRule: DiagnosticRule {
    let id = "smb"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        guard context.smbCPU > 5, !context.smbMounts.isEmpty else { return [] }

        return [FixSuggestion(
            id: "smb",
            title: L10n.t("rule.smb.title"),
            detail: L10n.t(
                "rule.smb.detail",
                context.smbMounts.prefix(2).joined(separator: ", "),
                Int(context.smbCPU)
            ),
            severity: context.smbCPU > 40 ? .medium : .low,
            command: "",
            admin: false,
            value: L10n.t("rule.smb.value", Int(context.smbCPU))
        )]
    }
}

struct MDMEnrollmentRule: DiagnosticRule {
    let id = "mdm"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        guard context.mdmEnrolled else { return [] }

        return [FixSuggestion(
            id: "mdm",
            title: L10n.t("rule.mdm.title"),
            detail: L10n.t("rule.mdm.detail"),
            severity: .low,
            command: "",
            admin: false,
            value: L10n.t("rule.mdm.value")
        )]
    }
}

struct HeavyAppsRule: DiagnosticRule {
    let id = "quit"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        var fixes: [FixSuggestion] = []
        for app in context.heavyApps.prefix(2) {
            fixes.append(FixSuggestion(
                id: "quit-\(app.bundleID)",
                title: L10n.t("rule.quit.title", app.name),
                detail: L10n.t("rule.quit.detail", app.name, Int(app.cpu)),
                severity: app.cpu > 150 ? .medium : .low,
                command: "",
                admin: false,
                value: L10n.t("rule.quit.value", Int(app.cpu)),
                nativeAction: "quit",
                nativeTarget: String(app.pid)
            ))
        }
        return fixes
    }
}

struct BrewServicesRule: DiagnosticRule {
    let id = "brew"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        var fixes: [FixSuggestion] = []
        for service in context.brewServices.prefix(3) {
            let safeName = service.replacingOccurrences(
                of: "[^A-Za-z0-9._@-]",
                with: "",
                options: .regularExpression
            )
            guard !safeName.isEmpty, safeName == service else { continue }
            fixes.append(FixSuggestion(
                id: "brew-\(service)",
                title: L10n.t("rule.brew.title", service),
                detail: L10n.t("rule.brew.detail", service, service),
                severity: .low,
                command: "brew services stop \(service)",
                admin: false,
                value: L10n.t("rule.brew.value"),
                undoCommand: "brew services start \(service)"
            ))
        }
        return fixes
    }
}

struct LaunchHelpersRule: DiagnosticRule {
    let id = "helper"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        var fixes: [FixSuggestion] = []
        for helper in context.helpers.prefix(3) {
            guard !ProbeParsers.isProtectedLabel(helper.label) else { continue }
            guard helper.plistPath != nil else { continue }
            guard helper.label.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else { continue }
            let domain = helper.admin ? "system" : "gui/$(id -u)"
            let command = "launchctl bootout \(domain)/\(helper.label) 2>/dev/null; launchctl disable \(domain)/\(helper.label) 2>/dev/null; true"
            var undo: String?
            if let plist = helper.plistPath, plist.range(of: "^/Library/|^" + NSHomeDirectory(), options: .regularExpression) != nil {
                undo = "launchctl enable \(domain)/\(helper.label); launchctl bootstrap \(domain) \"\(plist)\""
            }
            fixes.append(FixSuggestion(
                id: "helper-\(helper.label)",
                title: L10n.t("rule.helper.title", helper.friendlyName),
                detail: L10n.t(
                    "rule.helper.detail",
                    helper.label, helper.friendlyName
                ),
                severity: .low,
                command: command,
                admin: helper.admin,
                value: L10n.t("rule.helper.value"),
                undoCommand: undo
            ))
        }
        return fixes
    }
}

struct LoginItemsRule: DiagnosticRule {
    let id = "login"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        var fixes: [FixSuggestion] = []
        for name in context.loginItems where !name.isEmpty {
            guard name.range(of: "^[A-Za-z0-9 ._-]+$", options: .regularExpression) != nil else { continue }
            let escaped = name
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            fixes.append(FixSuggestion(
                id: "login-\(name)",
                title: L10n.t("rule.login.title", name),
                detail: L10n.t("rule.login.detail", name),
                severity: .low,
                command: "/usr/bin/osascript -e 'tell application \"System Events\" to delete login item \"\(escaped)\"'",
                admin: false,
                value: L10n.t("rule.login.value")
            ))
        }
        return fixes
    }
}

struct SleepAssertionsRule: DiagnosticRule {
    let id = "sleep-caffeinate"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        var fixes: [FixSuggestion] = []
        for assertion in context.sleepAssertions {
            if assertion.process == "caffeinate" {
                fixes.append(FixSuggestion(
                    id: "sleep-caffeinate-\(assertion.pid)",
                    title: L10n.t("rule.sleep_caffeinate.title"),
                    detail: L10n.t("rule.sleep_caffeinate.detail", assertion.pid),
                    severity: .medium,
                    command: "kill \(assertion.pid)",
                    admin: false,
                    value: L10n.t("rule.sleep_caffeinate.value", assertion.pid)
                ))
            }
        }
        return fixes
    }
}

struct PeripheralBatteryRule: DiagnosticRule {
    let id = "peripheral-battery"

    func evaluate(context: RuleContext) -> [FixSuggestion] {
        var fixes: [FixSuggestion] = []
        for peripheral in context.peripherals {
            if peripheral.percent <= 20 {
                let slug = peripheral.name.lowercased()
                    .replacingOccurrences(of: " ", with: "-")
                    .replacingOccurrences(of: "[^a-z0-9_-]", with: "", options: .regularExpression)
                fixes.append(FixSuggestion(
                    id: "peripheral-battery-\(slug)",
                    title: L10n.t("rule.peripheral.title", peripheral.name, peripheral.percent),
                    detail: L10n.t("rule.peripheral.detail", peripheral.name, peripheral.percent),
                    severity: peripheral.percent <= 10 ? .high : .medium,
                    command: "",
                    admin: false,
                    value: L10n.t("rule.peripheral.value", peripheral.percent)
                ))
            }
        }
        return fixes
    }
}

// MARK: - Rule Catalogue

enum Rules {
    private static let severityOrder: [Severity: Int] = [.high: 0, .medium: 1, .low: 2]

    static let allRules: [DiagnosticRule] = [
        BatteryHealthRule(),
        DiskSpaceRule(),
        MemoryPurgeRule(),
        NotificationCenterRule(),
        SleepTimerRule(),
        ThermalThrottlingRule(),
        WindowServerRule(),
        TimeMachineRule(),
        BackupActivityRule(),
        SpotlightRule(),
        DNSResponderRule(),
        SMBSharesRule(),
        MDMEnrollmentRule(),
        HeavyAppsRule(),
        BrewServicesRule(),
        LaunchHelpersRule(),
        LoginItemsRule(),
        SleepAssertionsRule(),
        PeripheralBatteryRule()
    ]

    static func build(_ context: RuleContext) -> [FixSuggestion] {
        var fixes: [FixSuggestion] = []
        for rule in allRules {
            fixes.append(contentsOf: rule.evaluate(context: context))
        }
        return fixes.sorted { (severityOrder[$0.severity] ?? 3) < (severityOrder[$1.severity] ?? 3) }
    }
}
