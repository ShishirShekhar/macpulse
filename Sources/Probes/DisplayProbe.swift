import Foundation
import AppKit

/// Reads the process CPU snapshot, Spotlight state and maps busy PIDs back to
/// real GUI apps so MacPulse can offer a normal Quit instead of a force kill.
enum DisplayProbe {
    private static let excludedProcesses: Set<String> = [
        "kernel_task", "windowserver", "launchd", "loginwindow", "finder",
        "notificationcenter", "usernoted", "mds", "mds_stores", "mdworker",
        "mdworker_shared", "backupd", "sysmond", "systemuiserver", "dock",
        "controlcenter", "macpulse", "spotlight", "coreaudiod", "powerd"
    ]

    static func sample() -> DisplaySample {
        let top = ProbeParsers.topProcesses(
            Shell.value("top -l 2 -o cpu -n 30 -stats pid,command,cpu 2>/dev/null")
        )
        let mdutil = Shell.value("mdutil -s / 2>/dev/null")
        let smbMounts = ProbeParsers.smbMounts(Shell.value("mount 2>/dev/null"))

        return DisplaySample(
            top: top,
            kernelTaskCPU: cpu(of: "kernel_task", in: top),
            windowServerCPU: cpu(of: "WindowServer", in: top),
            notificationCPU: max(
                cpu(of: "NotificationCenter", in: top),
                cpu(of: "usernoted", in: top)
            ),
            heavyApps: heavyApps(from: top),
            spotlightIndexing: ProbeParsers.spotlightIndexing(mdutil),
            backupdCPU: ProbeParsers.totalCPU(of: ["backupd"], in: top),
            spotlightCPU: ProbeParsers.totalCPU(
                of: ["mds", "mds_stores", "mdworker", "mdworker_shared"],
                in: top
            ),
            dnsCPU: ProbeParsers.totalCPU(of: ["mDNSResponder"], in: top),
            smbCPU: ProbeParsers.totalCPU(of: ["smbd"], in: top),
            smbMounts: smbMounts
        )
    }

    static func cpu(of name: String, in top: [TopProcess]) -> Double {
        top.first { $0.name.localizedCaseInsensitiveContains(name) }?.cpu ?? 0
    }

    static func heavyApps(from top: [TopProcess]) -> [HeavyApp] {
        let apps = NSWorkspace.shared.runningApplications
        guard !apps.isEmpty else { return [] }

        var byPID: [Int32: NSRunningApplication] = [:]
        for app in apps { byPID[app.processIdentifier] = app }

        var result: [HeavyApp] = []
        for process in top {
            guard process.cpu >= 60,
                  let pid = Int32(process.pid),
                  let app = byPID[pid],
                  app.activationPolicy == .regular,
                  app.bundleIdentifier != "com.macpulse.app" else { continue }
            let name = app.localizedName ?? process.name
            guard !excludedProcesses.contains(name.lowercased()) else { continue }
            guard !result.contains(where: { $0.pid == pid }) else { continue }
            result.append(HeavyApp(
                name: name,
                bundleID: app.bundleIdentifier ?? name,
                cpu: process.cpu,
                pid: pid
            ))
            if result.count >= 3 { break }
        }
        return result
    }
}
