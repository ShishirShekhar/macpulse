import Foundation
import AppKit

/// Generates a clean, privacy-preserving plain text and Markdown diagnostic report.
///
/// Invariants:
/// - Strictly local: Never sends data anywhere.
/// - Privacy first: Omits serial numbers, MAC addresses, machine hostnames,
///   usernames, and local file paths.
enum DiagnosticReport {
    static func generate(from result: CheckResult, appVersion: String = "1.7.0") -> String {
        var lines: [String] = []

        let statusLabel = result.score >= 80 ? "Optimal" : (result.score >= 60 ? "Fair" : "Needs Attention")

        lines.append("# MacPulse Diagnostic Report")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: result.date))")
        lines.append("MacPulse Version: v\(appVersion)")
        lines.append("")

        lines.append("## Overall Health")
        lines.append("- Score: \(result.score) / 100 (\(statusLabel))")
        if let subscores = result.subscores, !subscores.isEmpty {
            lines.append("- Score Breakdown:")
            for s in subscores {
                if s.points > 0 {
                    lines.append("  • \(s.title): -\(s.points) pts (\(s.note))")
                } else {
                    lines.append("  • \(s.title): 0 pts deducted")
                }
            }
        }
        lines.append("")

        lines.append("## Hardware & System Profile")
        if let prof = result.profile {
            lines.append("- Chip: \(prof.chip)")
            lines.append("- Cores: \(prof.cores) total (\(prof.performanceCores) performance, \(prof.efficiencyCores) efficiency)")
            lines.append("- Architecture: \(prof.isAppleSilicon ? "Apple Silicon" : "Intel")")
            lines.append("- Form Factor: \(prof.isLaptop ? "Laptop" : "Desktop")")
            lines.append("- Total Memory: \(Int(prof.ramGB)) GB")
            lines.append("- macOS Major Version: \(prof.osMajor)")
        } else {
            lines.append("- Model: \(result.modelName) (\(result.model))")
            lines.append("- OS Version: macOS \(result.osVersion)")
            lines.append("- Total Memory: \(Int(result.memTotalGB)) GB")
            lines.append("- CPU Cores: \(result.cpuCores)")
        }
        lines.append("- Uptime: \(result.uptime)")
        lines.append("")

        lines.append("## Primary Metrics")
        lines.append("### CPU & Thermals")
        lines.append("- Load: 1m: \(String(format: "%.2f", result.load1)), 5m: \(String(format: "%.2f", result.load5)), 15m: \(String(format: "%.2f", result.load15))")
        lines.append("- kernel_task: \(Int(result.kernelTaskCPU))% CPU (Status: \(result.thermalStatus.rawValue))")
        lines.append("- WindowServer: \(Int(result.windowServerCPU))% CPU (Status: \(result.windowServerStatus.rawValue))")
        lines.append("")

        lines.append("### Memory & Storage")
        lines.append("- Free RAM: \(Int(result.memFreePct))%")
        lines.append("- Compressed RAM: \(String(format: "%.2f", result.memCompressedGB)) GB")
        lines.append("- Swap Used: \(Int(result.swapUsedMB)) MB (Status: \(result.memoryStatus.rawValue))")
        lines.append("- Storage: \(Int(result.diskFreeGB)) GB free of \(Int(result.diskTotalGB)) GB (\(Int(result.diskFreePct))% available, Status: \(result.diskStatus.rawValue))")
        lines.append("")

        lines.append("### Power & Battery")
        if result.profile?.hasBattery ?? (result.batteryCondition != "No battery") {
            lines.append("- Battery Health: \(Int(result.batteryHealthPct))%")
            lines.append("- Battery Condition: \(result.batteryCondition)")
            lines.append("- Battery Cycles: \(result.batteryCycles)")
            lines.append("- Current Charge: \(result.batteryCharge)% (\(result.charging ? "Charging" : "Discharging"))")
        } else {
            lines.append("- Internal Battery: None (Desktop power)")
        }
        lines.append("- AC Sleep Timer: \(result.acSleepMinutes <= 0 ? "Disabled" : "\(result.acSleepMinutes) minutes")")
        if let assertions = result.sleepAssertions, !assertions.isEmpty {
            lines.append("- Sleep Assertions:")
            for a in assertions {
                lines.append("  • PID \(a.pid) (\(a.process)): \(a.assertionType)")
            }
        }
        if let peripherals = result.peripherals, !peripherals.isEmpty {
            lines.append("- Connected Peripherals:")
            for p in peripherals {
                lines.append("  • \(p.name): \(p.percent)%")
            }
        }
        lines.append("")

        lines.append("### Startup & System Services")
        lines.append("- Login Items Count: \(result.loginItems.count)")
        lines.append("- Launch Agents Count: \(result.launchAgentCount)")
        lines.append("")

        lines.append("## Recommendations (\(result.fixes.count))")
        if result.fixes.isEmpty {
            lines.append("No active recommendations. System is optimal.")
        } else {
            for fix in result.fixes {
                let adminNotice = fix.admin ? " [Requires Admin]" : ""
                lines.append("- [\(fix.severity.rawValue.uppercased())] \(fix.title)\(adminNotice)")
                lines.append("  Detail: \(fix.detail)")
                if !fix.command.isEmpty {
                    lines.append("  Action Command: `\(fix.command)`")
                }
            }
        }
        lines.append("")

        lines.append("## Top Processes")
        if result.topProcesses.isEmpty {
            lines.append("No process information available.")
        } else {
            for proc in result.topProcesses.prefix(8) {
                lines.append(String(format: "- %-24@ %6.1f%% CPU", proc.name, proc.cpu))
            }
        }
        lines.append("")
        lines.append("---")
        lines.append("*Report produced locally by MacPulse. Zero network telemetry transmitted.*")

        return lines.joined(separator: "\n")
    }

    /// Copies the generated report to the general pasteboard.
    static func copyToClipboard(_ report: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(report, forType: .string)
    }
}
