import Foundation

/// Typed result of one probe. Probes only read the machine; they never decide
/// anything. Rules and scoring consume these values, which keeps detection and
/// policy separate and testable.

struct LoadSample: Equatable {
    let load1: Double
    let load5: Double
    let load15: Double

    static let zero = LoadSample(load1: 0, load5: 0, load15: 0)
}

struct CPUSample: Equatable {
    let modelIdentifier: String
    let chip: String
    let cores: Int
    let performanceCores: Int
    let efficiencyCores: Int
    let isAppleSilicon: Bool
    let load: LoadSample
}

struct MemorySample: Equatable {
    let totalGB: Double
    let freePercent: Double
    let compressedGB: Double
    let swapUsedMB: Double
}

struct DiskSample: Equatable {
    let freeGB: Double
    let totalGB: Double

    var freePercent: Double {
        totalGB > 0 ? (freeGB / totalGB) * 100 : 0
    }
}

struct BatterySample: Equatable {
    let health: Double
    let cycles: Int
    let condition: String
    let charge: Int
    let charging: Bool
    let onAC: Bool
    let hasBattery: Bool

    static let none = BatterySample(
        health: 0,
        cycles: 0,
        condition: "No battery",
        charge: 0,
        charging: false,
        onAC: true,
        hasBattery: false
    )
}

/// A background helper MacPulse may offer to disable. `admin` is true only for
/// system-domain daemons, which need the administrator dialog.
struct HelperService: Equatable {
    let label: String
    let friendlyName: String
    let admin: Bool
    let plistPath: String?
}

/// A GUI app using a lot of CPU. MacPulse only ever offers a normal Quit.
struct HeavyApp: Equatable {
    let name: String
    let bundleID: String
    let cpu: Double
    let pid: Int32
}

struct DisplaySample {
    let top: [TopProcess]
    let kernelTaskCPU: Double
    let windowServerCPU: Double
    let notificationCPU: Double
    let heavyApps: [HeavyApp]
    let spotlightIndexing: Bool
    /// Aggregate CPU for processes that are never offered as app quits but are
    /// worth explaining: backups, indexing, DNS and SMB traffic.
    let backupdCPU: Double
    let spotlightCPU: Double
    let dnsCPU: Double
    let smbCPU: Double
    /// Mount points of currently mounted SMB shares, used for advice copy.
    let smbMounts: [String]
}

/// Time Machine state. A Mac with no backup disk is not failing, so this only
/// ever produces advice or a user-approved "start a backup" action.
struct BackupSample: Equatable {
    let hasDestination: Bool
    let lastBackup: Date?

    static let unknown = BackupSample(hasDestination: false, lastBackup: nil)
}

/// Whether this Mac is managed by an organization. MacPulse never changes
/// management settings; the rule is informational only.
struct ManagementSample: Equatable {
    let mdmEnrolled: Bool

    static let unmanaged = ManagementSample(mdmEnrolled: false)
}

struct StartupSample {
    let loginItems: [String]
    let launchAgentCount: Int
    let brewServices: [String]
    let helpers: [HelperService]
    /// True when the login items came from the cache because this scan could not
    /// ask for Automation permission (headless runs).
    let usedCachedLoginItems: Bool
}

struct SystemSample {
    let osVersion: String
    let osMajor: Int
    let uptime: String
    let acSleepMinutes: Int
}

/// A power management assertion held by a process preventing sleep or display off.
struct SleepAssertion: Codable, Equatable, Hashable {
    let pid: Int
    let process: String
    let assertionType: String
    let name: String
}

/// Sample of system-wide sleep assertions.
struct SleepAssertionSample: Equatable {
    let assertions: [SleepAssertion]
    let preventSystemSleep: Bool
    let preventDisplaySleep: Bool

    static let none = SleepAssertionSample(assertions: [], preventSystemSleep: false, preventDisplaySleep: false)
}

/// Battery percentage reported by a connected Bluetooth or HID peripheral.
struct PeripheralBattery: Codable, Equatable, Hashable {
    let name: String
    let percent: Int
}

