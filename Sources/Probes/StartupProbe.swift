import Foundation

/// Reads everything that starts automatically: login items, launch agents,
/// Homebrew services and third-party background helpers.
enum StartupProbe {
    static func sample(
        interactive: Bool,
        cachedLoginItems: [String],
        top: [TopProcess]
    ) -> StartupSample {
        // Headless scans cannot answer the Automation prompt, so keep the last
        // successful list instead of overwriting it with an empty one.
        let freshItems = interactive ? readLoginItems() : nil

        return StartupSample(
            loginItems: freshItems ?? cachedLoginItems,
            launchAgentCount: launchAgentCount(),
            brewServices: brewServices(),
            helpers: helpers(top: top),
            usedCachedLoginItems: freshItems == nil
        )
    }

    // MARK: - Login items

    private static func readLoginItems() -> [String]? {
        let script = "tell application \"System Events\" to get the name of every login item"
        let result = Shell.exec("/usr/bin/osascript", ["-e", script], timeout: 6)
        guard result.code == 0 else { return nil }
        return result.output
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Launch agents

    private static func launchAgentCount() -> Int {
        Int(Shell.value(
            "find ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons " +
            "-maxdepth 1 -name '*.plist' 2>/dev/null | wc -l"
        )) ?? 0
    }

    // MARK: - Homebrew

    private static func brewPath() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func brewServices() -> [String] {
        guard let brew = brewPath() else { return [] }

        let json = Shell.run("\(brew) services list --json", timeout: 6)
        if json.code == 0 {
            let names = ProbeParsers.brewServices(json.output)
            if !names.isEmpty { return names }
        }
        return ProbeParsers.brewServices(Shell.run("\(brew) services list", timeout: 6).output)
    }

    // MARK: - Helpers

    private static func helpers(top: [TopProcess]) -> [HelperService] {
        var cpuByPID: [String: Double] = [:]
        for process in top {
            cpuByPID[process.pid] = max(cpuByPID[process.pid] ?? 0, process.cpu)
        }

        let entries = ProbeParsers.launchctlEntries(
            Shell.value("launchctl list 2>/dev/null")
        )
        let candidates = ProbeParsers.helperCandidates(entries: entries, cpuByPID: cpuByPID)
        let userPlists = userAgentPathMap()

        var helpers: [HelperService] = []
        for candidate in candidates {
            guard let plistPath = userPlists[candidate.label.lowercased()] ?? userAgentPath(for: candidate.label) else {
                // If there is no backing .plist on disk in ~/Library/LaunchAgents or
                // /Library/LaunchAgents, this is an ephemeral process or application
                // session, NOT an installed background launch agent. Never offer to disable it.
                continue
            }
            helpers.append(HelperService(
                label: candidate.label,
                friendlyName: ProbeParsers.friendlyHelperName(candidate.label),
                admin: false,
                plistPath: plistPath
            ))
        }

        // System-wide daemons (VPNs, VM runtimes, remote access) do not appear in
        // the per-user `launchctl list`.
        let daemonDirectory = "/Library/LaunchDaemons"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: daemonDirectory)) ?? []
        for file in names.sorted() where file.hasSuffix(".plist") {
            let label = String(file.dropLast(6))
            guard ProbeParsers.isVendorLabel(label),
                  !helpers.contains(where: { $0.label == label }) else { continue }

            let printed = Shell.run("launchctl print system/\(label)", timeout: 2)
            guard printed.code == 0 else { continue }
            let state = printed.output
            guard state.contains("state = running") || state.contains("pid = ") else { continue }

            helpers.append(HelperService(
                label: label,
                friendlyName: ProbeParsers.friendlyHelperName(label),
                admin: true,
                plistPath: "\(daemonDirectory)/\(file)"
            ))
            if helpers.count >= 8 { break }
        }

        return helpers
    }

    private static func userAgentPathMap() -> [String: String] {
        var map: [String: String] = [:]
        let directories = [
            NSHomeDirectory() + "/Library/LaunchAgents",
            "/Library/LaunchAgents"
        ]
        for dir in directories {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for file in files where file.hasSuffix(".plist") {
                let fullPath = "\(dir)/\(file)"
                let fileBase = String(file.dropLast(6))
                map[fileBase.lowercased()] = fullPath

                if let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                   let plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any],
                   let label = plist["Label"] as? String {
                    map[label.lowercased()] = fullPath
                }
            }
        }
        return map
    }

    private static func userAgentPath(for label: String) -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/Library/LaunchAgents/\(label).plist",
            "/Library/LaunchAgents/\(label).plist"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }
}
