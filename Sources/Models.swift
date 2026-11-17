import Foundation

enum Status: String, Codable {
    case good, warn, bad
}

enum Severity: String, Codable {
    case high, medium, low

    var label: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

struct TopProcess: Codable, Identifiable, Hashable {
    var id: String { pid + name }
    let pid: String
    let name: String
    let cpu: Double
}

struct FixSuggestion: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let severity: Severity
    let command: String
    let admin: Bool
    let value: String

    /// Optional shell command that reverses `command`, when the action is reversible.
    var undoCommand: String? = nil
    /// Native (non-shell) action, e.g. "quit" for a graceful app quit.
    var nativeAction: String? = nil
    /// Target of `nativeAction`, e.g. a process identifier as a string.
    var nativeTarget: String? = nil

    var isActionable: Bool {
        !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nativeAction != nil
    }
}

/// What kind of Mac this is. Rules use it so that a desktop never gets laptop
/// advice and Intel machines are not judged by Apple Silicon assumptions.
struct DeviceProfile: Codable, Hashable {
    let modelIdentifier: String
    let chip: String
    let cores: Int
    let performanceCores: Int
    let efficiencyCores: Int
    let isAppleSilicon: Bool
    let isLaptop: Bool
    let hasBattery: Bool
    let osMajor: Int
    let ramGB: Double
}

struct CheckResult: Codable {
    let date: Date
    let model: String
    let modelName: String
    let osVersion: String
    let uptime: String
    let cpuCores: Int
    let load1: Double
    let load5: Double
    let load15: Double
    let memTotalGB: Double
    let memFreePct: Double
    let memCompressedGB: Double
    let swapUsedMB: Double
    let diskFreeGB: Double
    let diskTotalGB: Double
    let batteryHealthPct: Double
    let batteryCycles: Int
    let batteryCondition: String
    let batteryCharge: Int
    let charging: Bool
    let onAC: Bool
    let kernelTaskCPU: Double
    let windowServerCPU: Double
    let notificationCPU: Double
    let spotlightIndexing: Bool
    let acSleepMinutes: Int
    let loginItems: [String]
    let launchAgentCount: Int
    let topProcesses: [TopProcess]
    let fixes: [FixSuggestion]
    let score: Int

    /// Per-component breakdown. Optional so older cached scans still decode.
    var subscores: [Subscore]? = nil
    /// The detected device profile is stored so the UI and later runs know what
    /// kind of Mac produced this scan.
    var profile: DeviceProfile? = nil
    /// Active sleep assertions preventing system or display sleep.
    var sleepAssertions: [SleepAssertion]? = nil
    /// Connected Bluetooth and HID peripherals reporting battery levels.
    var peripherals: [PeripheralBattery]? = nil
}

extension CheckResult {
    var diskFreePct: Double {
        diskTotalGB > 0 ? (diskFreeGB / diskTotalGB) * 100 : 0
    }

    var cpuStatus: Status {
        if load1 <= Double(cpuCores) * 0.5 { return .good }
        if load1 <= Double(cpuCores) * 1.0 { return .warn }
        return .bad
    }

    var memoryStatus: Status {
        if memFreePct >= 30 { return .good }
        if memFreePct >= 15 { return .warn }
        return .bad
    }

    var diskStatus: Status {
        if diskFreePct >= 20 { return .good }
        if diskFreePct >= 10 { return .warn }
        return .bad
    }

    var batteryStatus: Status {
        if let peripherals = peripherals, peripherals.contains(where: { $0.percent <= 10 }) {
            return .bad
        }
        if let peripherals = peripherals, peripherals.contains(where: { $0.percent <= 20 }) {
            return .warn
        }
        if batteryCondition == "No battery" { return .good }
        if batteryCondition == "Normal" && batteryHealthPct >= 80 { return .good }
        if batteryHealthPct >= 60 { return .warn }
        return .bad
    }

    var thermalStatus: Status {
        if kernelTaskCPU < 10 { return .good }
        if kernelTaskCPU < 25 { return .warn }
        return .bad
    }

    var startupStatus: Status {
        if loginItems.isEmpty && launchAgentCount <= 4 { return .good }
        if launchAgentCount <= 8 { return .warn }
        return .bad
    }

    var windowServerStatus: Status {
        if windowServerCPU < 20 { return .good }
        if windowServerCPU < 45 { return .warn }
        return .bad
    }

    var spotlightStatus: Status {
        spotlightIndexing ? .warn : .good
    }

    var sleepStatus: Status {
        if let assertions = sleepAssertions, assertions.contains(where: { $0.process == "caffeinate" }) {
            return .warn
        }
        if acSleepMinutes <= 0 || acSleepMinutes > 10 { return .good }
        if acSleepMinutes > 5 { return .warn }
        return .bad
    }

    var scoreLabel: String {
        switch score {
        case 85...: return "Running great"
        case 70..<85: return "Mostly healthy"
        case 50..<70: return "Needs attention"
        default: return "Needs work"
        }
    }

    var attentionItems: [String] {
        var items: [String] = []
        if batteryStatus != .good {
            items.append("Battery health is \(String(format: "%.1f", batteryHealthPct))% — \(batteryCondition.lowercased())")
        }
        if thermalStatus == .bad {
            items.append("CPU is being throttled (kernel_task \(Int(kernelTaskCPU))%)")
        }
        if cpuStatus == .bad {
            items.append("Load average is high at \(String(format: "%.1f", load1))")
        }
        if memoryStatus == .bad {
            items.append("Memory is tight — only \(Int(memFreePct))% free")
        }
        if diskStatus != .good {
            items.append("Low disk space — \(Int(diskFreeGB)) GB free")
        }
        if acSleepMinutes > 0 && acSleepMinutes <= 5 {
            items.append("Mac sleeps after \(acSleepMinutes) min on power")
        }
        if notificationCPU > 5 {
            items.append("Notification Center is using \(Int(notificationCPU))% CPU")
        }
        if let assertions = sleepAssertions, assertions.contains(where: { $0.process == "caffeinate" }) {
            items.append("Sleep is prevented by background caffeinate process")
        }
        if let peripherals = peripherals {
            for p in peripherals where p.percent <= 20 {
                items.append("\(p.name) battery is low (\(p.percent)%)")
            }
        }
        return items
    }
}
