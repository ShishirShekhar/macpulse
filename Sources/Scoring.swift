import Foundation

/// One component of the health score. `points` is what this component took
/// away from 100, so a perfect component has 0 and the numbers add up.
struct Subscore: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let points: Int
    let note: String
}

struct ScoreResult: Equatable {
    let score: Int
    let subscores: [Subscore]
}

/// Everything the score depends on. Kept separate from `CheckResult` so scoring
/// can be tested with plain values and no machine access.
struct ScoreInput: Equatable {
    var cpuCores: Int
    var load1: Double
    var memFreePct: Double
    var swapUsedMB: Double
    var diskFreePct: Double
    var hasBattery: Bool
    var batteryHealthPct: Double
    var batteryCondition: String
    var kernelTaskCPU: Double
    var notificationCPU: Double
    var acSleepMinutes: Int
    var launchAgentCount: Int
    var windowServerCPU: Double
    var interactive: Bool
}

/// The single place that turns measurements into a score. Weights are documented
/// in AGENTS.md §5; change them here and the tests will show the difference.
enum Scoring {
    static func evaluate(_ input: ScoreInput) -> ScoreResult {
        var subscores: [Subscore] = []

        // CPU load, normalised per logical core.
        let cpuPoints: Int
        let coreLoad = Double(max(1, input.cpuCores)) * 1.5
        let softLoad = Double(max(1, input.cpuCores)) * 0.8
        if input.load1 > coreLoad {
            cpuPoints = 20
        } else if input.load1 > softLoad {
            cpuPoints = 10
        } else {
            cpuPoints = 0
        }
        subscores.append(Subscore(
            id: "cpu",
            title: "CPU load",
            points: cpuPoints,
            note: String(format: "%.2f on %d cores", input.load1, input.cpuCores)
        ))

        // Memory pressure and swap.
        let memoryPoints: Int
        if input.memFreePct < 10 || input.swapUsedMB > 1024 {
            memoryPoints = 15
        } else if input.memFreePct < 25 {
            memoryPoints = 8
        } else {
            memoryPoints = 0
        }
        subscores.append(Subscore(
            id: "memory",
            title: "Memory",
            points: memoryPoints,
            note: "\(Int(input.memFreePct))% free, \(Int(input.swapUsedMB)) MB swap"
        ))

        // Startup disk space.
        let storagePoints: Int
        if input.diskFreePct < 10 {
            storagePoints = 15
        } else if input.diskFreePct < 20 {
            storagePoints = 7
        } else {
            storagePoints = 0
        }
        subscores.append(Subscore(
            id: "storage",
            title: "Storage",
            points: storagePoints,
            note: "\(Int(input.diskFreePct))% free"
        ))

        // Battery hardware, only when there is a battery.
        let batteryPoints: Int
        if input.hasBattery {
            if input.batteryHealthPct < 60 {
                batteryPoints = 25
            } else if input.batteryCondition != "Normal" {
                batteryPoints = 10
            } else {
                batteryPoints = 0
            }
        } else {
            batteryPoints = 0
        }
        subscores.append(Subscore(
            id: "battery",
            title: "Battery",
            points: batteryPoints,
            note: input.hasBattery
                ? "\(Int(input.batteryHealthPct))% health, \(input.batteryCondition.lowercased())"
                : "No battery"
        ))

        // Thermal throttling, visible as kernel_task CPU.
        let thermalPoints: Int
        if input.kernelTaskCPU > 30 {
            thermalPoints = 15
        } else if input.kernelTaskCPU > 15 {
            thermalPoints = 5
        } else {
            thermalPoints = 0
        }
        subscores.append(Subscore(
            id: "thermals",
            title: "Thermals",
            points: thermalPoints,
            note: "kernel_task \(Int(input.kernelTaskCPU))%"
        ))

        // Stuck Notification Center.
        let notificationPoints = input.notificationCPU > 10 ? 5 : 0
        subscores.append(Subscore(
            id: "notifications",
            title: "Notifications",
            points: notificationPoints,
            note: "\(Int(input.notificationCPU))% CPU"
        ))

        // Startup clutter.
        let startupPoints = input.launchAgentCount > 8 ? 5 : 0
        subscores.append(Subscore(
            id: "startup",
            title: "Startup items",
            points: startupPoints,
            note: "\(input.launchAgentCount) launch agents"
        ))

        // WindowServer is only meaningful when a GUI session is compositing.
        let displayPoints = (input.interactive && input.windowServerCPU > 45) ? 5 : 0
        subscores.append(Subscore(
            id: "display",
            title: "WindowServer",
            points: displayPoints,
            note: input.interactive
                ? "\(Int(input.windowServerCPU))% CPU"
                : "Not scored in a background check"
        ))

        // Short sleep timer on AC power.
        let sleepPoints = (input.acSleepMinutes > 0 && input.acSleepMinutes <= 5) ? 5 : 0
        subscores.append(Subscore(
            id: "sleep",
            title: "Auto-sleep",
            points: sleepPoints,
            note: input.acSleepMinutes <= 0
                ? "Never sleeps on power"
                : "\(input.acSleepMinutes) min on power"
        ))

        let deducted = subscores.reduce(0) { $0 + $1.points }
        return ScoreResult(score: max(0, min(100, 100 - deducted)), subscores: subscores)
    }
}
