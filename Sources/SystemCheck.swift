import Foundation
import AppKit

enum SystemCheck {
    // MARK: - Public

    static func collect(interactive: Bool = true) -> CheckResult {
        let model = Shell.value("sysctl -n hw.model")
        let chip = Shell.value("sysctl -n machdep.cpu.brand_string")
        let osVersion = Shell.value("sw_vers -productVersion")
        let cores = Int(Shell.value("sysctl -n hw.ncpu")) ?? 8
        let performanceCores = Int(Shell.value("sysctl -n hw.perflevel0.physicalcpu")) ?? 0
        let efficiencyCores = Int(Shell.value("sysctl -n hw.perflevel1.physicalcpu")) ?? 0
        let isAppleSilicon = Shell.value("sysctl -n hw.optional.arm64") == "1"

        let loadParts = numbers(in: Shell.value("sysctl -n vm.loadavg"))
        let load1 = loadParts.count > 0 ? loadParts[0] : 0
        let load5 = loadParts.count > 1 ? loadParts[1] : 0
        let load15 = loadParts.count > 2 ? loadParts[2] : 0

        let memTotalGB = (Double(Shell.value("sysctl -n hw.memsize")) ?? 0) / 1_073_741_824
        let pressure = Shell.value("memory_pressure 2>/dev/null | tail -3")
        let memFreePct = capture("free percentage:\\s*(\\d+)", pressure).flatMap(Double.init) ?? 0

        let vmStat = Shell.value("vm_stat")
        let pageSize = capture("page size of (\\d+) bytes", vmStat).flatMap(Double.init) ?? 16384
        let compressorPages = capture("Pages occupied by compressor:\\s*(\\d+)", vmStat).flatMap(Double.init) ?? 0
        let memCompressedGB = compressorPages * pageSize / 1_073_741_824

        let swapText = Shell.value("sysctl -n vm.swapusage")
        let swapUsedMB = capture("used = ([0-9.]+)M", swapText).flatMap(Double.init) ?? 0

        let (diskFreeGB, diskTotalGB) = diskSpace()
        let battery = readBattery()

        let profile = DeviceProfile(
            modelIdentifier: model,
            chip: chip,
            cores: cores,
            performanceCores: performanceCores > 0 ? performanceCores : cores,
            efficiencyCores: efficiencyCores,
            isAppleSilicon: isAppleSilicon,
            isLaptop: model.hasPrefix("MacBook"),
            hasBattery: battery.hasBattery,
            osMajor: Int(osVersion.split(separator: ".").first ?? "") ?? 0,
            ramGB: memTotalGB
        )

        let top = parseTop(Shell.value("top -l 2 -o cpu -n 30 -stats pid,command,cpu 2>/dev/null"))
        let kernelCPU = top.first { $0.name.localizedCaseInsensitiveContains("kernel_task") }?.cpu ?? 0
        let windowCPU = top.first { $0.name.localizedCaseInsensitiveContains("WindowServer") }?.cpu ?? 0
        let notifCPU = max(
            top.first { $0.name.localizedCaseInsensitiveContains("NotificationCenter") }?.cpu ?? 0,
            top.first { $0.name.localizedCaseInsensitiveContains("usernoted") }?.cpu ?? 0
        )

        let mdutil = Shell.value("mdutil -s / 2>/dev/null")
        let indexing = mdutil.contains("Indexing enabled") && !mdutil.contains("disabled")

        // Headless scans cannot ask for Automation permission, so keep the last
        // successful login-item list instead of overwriting it with an empty one.
        let loginItems: [String]
        if interactive, let freshItems = readLoginItems() {
            loginItems = freshItems
        } else {
            loginItems = load()?.loginItems ?? []
        }

        let launchAgents = Int(Shell.value("find ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons -maxdepth 1 -name '*.plist' 2>/dev/null | wc -l")) ?? 0
        let acSleep = readACSleep()

        let uptime = formatUptime(bootSeconds: capture("sec = (\\d+)", Shell.value("sysctl -n kern.boottime")).flatMap(Double.init) ?? 0)

        let diskFreePct = diskTotalGB > 0 ? (diskFreeGB / diskTotalGB) * 100 : 0
        let context = RuleContext(
            profile: profile,
            interactive: interactive,
            notificationCPU: notifCPU,
            acSleepMinutes: acSleep,
            loginItems: loginItems,
            memFreePct: memFreePct,
            swapUsedMB: swapUsedMB,
            diskFreeGB: diskFreeGB,
            diskFreePct: diskFreePct,
            windowServerCPU: windowCPU,
            kernelTaskCPU: kernelCPU,
            batteryHealthPct: battery.health,
            batteryCondition: battery.condition,
            batteryCycles: battery.cycles,
            brewServices: readBrewServices(),
            helpers: readHelpers(top: top),
            heavyApps: readHeavyApps(top: top)
        )
        let fixes = Rules.build(context)

        let provisional = CheckResult(
            date: Date(),
            model: model,
            modelName: friendlyModel(model, chip: chip),
            osVersion: osVersion,
            uptime: uptime,
            cpuCores: cores,
            load1: load1,
            load5: load5,
            load15: load15,
            memTotalGB: memTotalGB,
            memFreePct: memFreePct,
            memCompressedGB: memCompressedGB,
            swapUsedMB: swapUsedMB,
            diskFreeGB: diskFreeGB,
            diskTotalGB: diskTotalGB,
            batteryHealthPct: battery.health,
            batteryCycles: battery.cycles,
            batteryCondition: battery.condition,
            batteryCharge: battery.charge,
            charging: battery.charging,
            onAC: battery.onAC,
            kernelTaskCPU: kernelCPU,
            windowServerCPU: windowCPU,
            notificationCPU: notifCPU,
            spotlightIndexing: indexing,
            acSleepMinutes: acSleep,
            loginItems: loginItems,
            launchAgentCount: launchAgents,
            topProcesses: Array(top.prefix(8)),
            fixes: fixes,
            score: 100
        )

        return rescore(provisional, interactive: interactive)
    }

    // MARK: - Persistence

    static var supportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacPulse", isDirectory: true)
    }

    static var storeURL: URL {
        supportDirectory.appendingPathComponent("last-check.json")
    }

    static func save(_ result: CheckResult) {
        do {
            try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(result)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            NSLog("MacPulse save failed: \(error)")
        }
    }

    static func load() -> CheckResult? {
        guard let data = try? Data(contentsOf: storeURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CheckResult.self, from: data)
    }

    // MARK: - Detectors

    private static func brewPath() -> String? {
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Homebrew services that are currently started. Uses the machine-readable
    /// output first and falls back to the table format on older Homebrew versions.
    private static func readBrewServices() -> [String] {
        guard let brew = brewPath() else { return [] }

        let jsonRun = Shell.run("\(brew) services list --json", timeout: 6)
        if jsonRun.code == 0,
           let data = jsonArrayData(jsonRun.output),
           let object = try? JSONSerialization.jsonObject(with: data),
           let items = object as? [[String: Any]] {
            return items.compactMap { item in
                guard let name = item["name"] as? String else { return nil }
                let status = (item["status"] as? String)?.lowercased()
                return status == "started" ? name : nil
            }
        }

        let text = Shell.run("\(brew) services list", timeout: 6).output
        return text.split(separator: "\n").dropFirst().compactMap { line in
            let parts = line.split(omittingEmptySubsequences: true, whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 2, parts[1].lowercased() == "started" else { return nil }
            return String(parts[0])
        }
    }

    private static func jsonArrayData(_ text: String) -> Data? {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]"),
              start < end else { return nil }
        return String(text[start...end]).data(using: .utf8)
    }

    /// Labels that are recognisably third-party background helpers. Everything
    /// else is ignored: MacPulse never offers to disable an unknown service.
    private static let vendorHints: [String] = [
        "docker", "vmware", "parallels", "virtualbox", "zerotier", "teamviewer",
        "logmein", "huion", "wacom", "razer", "logi", "logitech", "nordvpn",
        "expressvpn", "surfshark", "cisco", "anydesk", "parsec", "splashtop",
        "dropbox", "google", "microsoft", "jamf", "oracle", "tencent", "alipay",
        "baidu", "zoom", "box", "amazon", "obs", "elgato", "citrix", "realvnc"
    ]

    /// Labels MacPulse must never offer to disable, even when they are busy.
    private static func isProtectedLabel(_ label: String) -> Bool {
        let lower = label.lowercased()
        return lower.hasPrefix("com.apple.")
            || lower.hasPrefix("com.macpulse.")
            || lower.hasPrefix("homebrew.")
            || lower.hasPrefix("com.openssh.")
    }

    private static func isVendorLabel(_ label: String) -> Bool {
        guard !isProtectedLabel(label) else { return false }
        let lower = label.lowercased()
        return vendorHints.contains { lower.contains($0) }
    }

    private static func readHelpers(top: [TopProcess]) -> [HelperService] {
        var helpers: [HelperService] = []
        var seen = Set<String>()

        var cpuByPID: [String: Double] = [:]
        for process in top {
            cpuByPID[process.pid] = max(cpuByPID[process.pid] ?? 0, process.cpu)
        }

        // Per-user agents: shown when the label is a known vendor, or when the
        // agent is actually consuming CPU right now.
        let list = Shell.value("launchctl list 2>/dev/null")
        for line in list.split(separator: "\n").dropFirst() {
            let parts = line.split(omittingEmptySubsequences: true, whereSeparator: { $0 == "\t" || $0 == " " })
            guard parts.count >= 3 else { continue }
            let pid = String(parts[0])
            let label = String(parts[parts.count - 1])
            guard !label.isEmpty, !seen.contains(label), !isProtectedLabel(label) else { continue }

            let vendor = isVendorLabel(label)
            let busy = pid != "-" && (cpuByPID[pid] ?? 0) >= 8
            guard vendor || busy else { continue }

            seen.insert(label)
            helpers.append(HelperService(
                label: label,
                friendlyName: friendlyHelperName(label),
                admin: false,
                plistPath: userAgentPath(for: label)
            ))
        }

        // System-wide daemons (VPNs, VM runtimes, remote access) do not appear in
        // the per-user `launchctl list`.
        let daemonDirectory = "/Library/LaunchDaemons"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: daemonDirectory)) ?? []
        for file in names where file.hasSuffix(".plist") {
            let label = String(file.dropLast(6))
            guard isVendorLabel(label), !seen.contains(label) else { continue }
            let printed = Shell.run("launchctl print system/\(label)", timeout: 2)
            guard printed.code == 0 else { continue }
            let state = printed.output
            guard state.contains("state = running") || state.contains("pid = ") else { continue }
            seen.insert(label)
            helpers.append(HelperService(
                label: label,
                friendlyName: friendlyHelperName(label),
                admin: true,
                plistPath: "\(daemonDirectory)/\(file)"
            ))
            if helpers.count >= 8 { break }
        }

        return helpers
    }

    private static func userAgentPath(for label: String) -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/Library/LaunchAgents/\(label).plist",
            "/Library/LaunchAgents/\(label).plist"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private static func friendlyHelperName(_ label: String) -> String {
        let lower = label.lowercased()
        let map: [(String, String)] = [
            ("docker", "Docker"), ("vmware", "VMware"), ("parallels", "Parallels"),
            ("virtualbox", "VirtualBox"), ("zerotier", "ZeroTier"),
            ("teamviewer", "TeamViewer"), ("logmein", "LogMeIn"),
            ("huion", "Huion tablet"), ("wacom", "Wacom tablet"),
            ("nordvpn", "NordVPN"), ("expressvpn", "ExpressVPN"),
            ("surfshark", "Surfshark"), ("cisco", "Cisco"),
            ("anydesk", "AnyDesk"), ("parsec", "Parsec"),
            ("splashtop", "Splashtop"), ("dropbox", "Dropbox"),
            ("google", "Google updater"), ("microsoft", "Microsoft updater"),
            ("jamf", "Jamf"), ("oracle", "Oracle"), ("tencent", "Tencent"),
            ("alipay", "Alipay"), ("baidu", "Baidu"), ("zoom", "Zoom"),
            ("razer", "Razer"), ("logi", "Logitech"), ("amazon", "Amazon"),
            ("obs", "OBS"), ("elgato", "Elgato"), ("citrix", "Citrix"),
            ("realvnc", "RealVNC")
        ]
        for (needle, name) in map where lower.contains(needle) { return name }
        let last = label.split(separator: ".").last.map(String.init) ?? label
        return last
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }

    private static let excludedProcesses: Set<String> = [
        "kernel_task", "windowserver", "launchd", "loginwindow", "finder",
        "notificationcenter", "usernoted", "mds", "mds_stores", "mdworker",
        "mdworker_shared", "backupd", "sysmond", "systemuiserver", "dock",
        "controlcenter", "macpulse", "spotlight", "coreaudiod", "powerd"
    ]

    /// Maps the busiest `top` processes back to real GUI applications, so the
    /// user can be offered a normal Quit instead of a force kill.
    private static func readHeavyApps(top: [TopProcess]) -> [HeavyApp] {
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

    // MARK: - Battery

    private struct BatteryInfo {
        let health: Double
        let cycles: Int
        let condition: String
        let charge: Int
        let charging: Bool
        let onAC: Bool
        let hasBattery: Bool
    }

    private static func readBattery() -> BatteryInfo {
        let io = Shell.value("ioreg -rn AppleSmartBattery")
        let design = capture("\"DesignCapacity\"\\s*=\\s*(\\d+)", io).flatMap(Double.init) ?? 0
        var full = capture("\"FullChargeCapacity\"\\s*=\\s*(\\d+)", io).flatMap(Double.init) ?? 0
        if full == 0 {
            full = capture("\"AppleRawMaxCapacity\"\\s*=\\s*(\\d+)", io).flatMap(Double.init) ?? 0
        }
        let cycles = Int(capture("\"CycleCount\"\\s*=\\s*(\\d+)", io) ?? "0") ?? 0
        let charge = Int(capture("\"CurrentCapacity\"\\s*=\\s*(\\d+)", io) ?? "0") ?? 0
        let external = (capture("\"ExternalConnected\"\\s*=\\s*(Yes|No)", io) ?? "No") == "Yes"
        let charging = (capture("\"IsCharging\"\\s*=\\s*(Yes|No)", io) ?? "No") == "Yes"

        let hasBattery = design > 0 && full > 0
        let health = hasBattery ? min(100, (full / design) * 100) : 0
        let condition: String
        if !hasBattery {
            condition = "No battery"
        } else if health >= 80 && cycles < 1000 {
            condition = "Normal"
        } else {
            condition = "Service Recommended"
        }

        return BatteryInfo(
            health: health,
            cycles: cycles,
            condition: condition,
            charge: charge,
            charging: charging,
            onAC: external,
            hasBattery: hasBattery
        )
    }

    // MARK: - Parsing helpers

    private static func numbers(in text: String) -> [Double] {
        let pattern = "[-+]?[0-9]*\\.?[0-9]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.matches(in: text, range: range).compactMap { match in
            Double((text as NSString).substring(with: match.range))
        }
    }

    private static func capture(_ pattern: String, _ text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return nil }
        return ns.substring(with: match.range(at: 1))
    }

    private static func parseTop(_ text: String) -> [TopProcess] {
        let lines = text.components(separatedBy: "\n")
        guard let header = lines.lastIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("PID") }) else {
            return []
        }
        var result: [TopProcess] = []
        for line in lines[(header + 1)...] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 3, let cpu = Double(parts[parts.count - 1]) else { continue }
            let pid = String(parts[0])
            let name = parts.dropFirst().dropLast().joined(separator: " ")
            if name.isEmpty { continue }
            result.append(TopProcess(pid: pid, name: name, cpu: cpu))
        }
        return result
    }

    /// Returns nil when macOS could not read the list (for example because the
    /// Automation prompt was never answered), so callers can keep cached data.
    private static func readLoginItems() -> [String]? {
        let script = "tell application \"System Events\" to get the name of every login item"
        let result = Shell.exec("/usr/bin/osascript", ["-e", script], timeout: 6)
        guard result.code == 0 else { return nil }
        return result.output
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func readACSleep() -> Int {
        let text = Shell.value("pmset -g custom")
        var inAC = false
        var minutes = 0
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("AC Power:") { inAC = true; continue }
            if line.hasPrefix("Battery Power:") { inAC = false; continue }
            if inAC && line.hasPrefix("sleep") {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                if let last = parts.last, let value = Int(last) { minutes = value }
            }
        }
        return minutes
    }

    private static func diskSpace() -> (free: Double, total: Double) {
        let output = Shell.value("df -k /System/Volumes/Data 2>/dev/null | tail -1")
        let parts = output.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard parts.count >= 4,
              let total = Double(parts[1]),
              let free = Double(parts[3]) else { return (0, 0) }
        return (free / 1_048_576, total / 1_048_576)
    }

    private static func formatUptime(bootSeconds: Double) -> String {
        guard bootSeconds > 0 else { return "—" }
        let seconds = max(0, Int(Date().timeIntervalSince1970 - bootSeconds))
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private static func friendlyModel(_ identifier: String, chip: String) -> String {
        let name: String
        switch identifier {
        case "MacBookAir10,1": name = "MacBook Air (M1, 2020)"
        case "MacBookAir10,2": name = "MacBook Air (M2, 2022)"
        case "Mac14,2": name = "MacBook Air (M2, 2022)"
        case "Mac14,15": name = "MacBook Air (M2, 2023)"
        case "Mac15,12": name = "MacBook Air (M3, 2024)"
        case "MacBookPro17,1": name = "MacBook Pro (M1, 2020)"
        case "MacBookPro18,3": name = "MacBook Pro 14\" (M1 Pro, 2021)"
        case "MacBookPro18,4": name = "MacBook Pro 14\" (M1 Max, 2021)"
        case "Mac13,1": name = "Mac Studio (M1 Max, 2022)"
        case "Mac13,2": name = "Mac Studio (M1 Ultra, 2022)"
        case "Macmini9,1": name = "Mac mini (M1, 2020)"
        case "iMac21,1": name = "iMac 24\" (M1, 2021)"
        default:
            if identifier.hasPrefix("MacBookAir") { name = "MacBook Air" }
            else if identifier.hasPrefix("MacBookPro") { name = "MacBook Pro" }
            else if identifier.hasPrefix("MacBook") { name = "MacBook" }
            else if identifier.hasPrefix("Macmini") { name = "Mac mini" }
            else if identifier.hasPrefix("iMac") { name = "iMac" }
            else if identifier.hasPrefix("MacPro") { name = "Mac Pro" }
            else if identifier.hasPrefix("Mac") { name = "Mac" }
            else { name = identifier }
        }
        if chip.isEmpty || chip == identifier { return name }
        return "\(name) · \(chip)"
    }

    private static func rescore(_ result: CheckResult, interactive: Bool) -> CheckResult {
        var score = 100

        if result.load1 > Double(result.cpuCores) * 1.5 {
            score -= 20
        } else if result.load1 > Double(result.cpuCores) * 0.8 {
            score -= 10
        }

        if result.memFreePct < 10 || result.swapUsedMB > 1024 {
            score -= 15
        } else if result.memFreePct < 25 {
            score -= 8
        }

        if result.diskFreePct < 10 {
            score -= 15
        } else if result.diskFreePct < 20 {
            score -= 7
        }

        if result.batteryCondition != "No battery" {
            if result.batteryHealthPct < 60 {
                score -= 25
            } else if result.batteryCondition != "Normal" {
                score -= 10
            }
        }

        if result.kernelTaskCPU > 30 {
            score -= 15
        } else if result.kernelTaskCPU > 15 {
            score -= 5
        }

        if result.notificationCPU > 10 { score -= 5 }
        if result.acSleepMinutes > 0 && result.acSleepMinutes <= 5 { score -= 5 }
        if result.launchAgentCount > 8 { score -= 5 }
        // Nothing is compositing during a headless scan, so WindowServer would
        // always look idle. Only score it when a real GUI scan ran.
        if interactive && result.windowServerCPU > 45 { score -= 5 }

        score = max(0, min(100, score))

        return CheckResult(
            date: result.date,
            model: result.model,
            modelName: result.modelName,
            osVersion: result.osVersion,
            uptime: result.uptime,
            cpuCores: result.cpuCores,
            load1: result.load1,
            load5: result.load5,
            load15: result.load15,
            memTotalGB: result.memTotalGB,
            memFreePct: result.memFreePct,
            memCompressedGB: result.memCompressedGB,
            swapUsedMB: result.swapUsedMB,
            diskFreeGB: result.diskFreeGB,
            diskTotalGB: result.diskTotalGB,
            batteryHealthPct: result.batteryHealthPct,
            batteryCycles: result.batteryCycles,
            batteryCondition: result.batteryCondition,
            batteryCharge: result.batteryCharge,
            charging: result.charging,
            onAC: result.onAC,
            kernelTaskCPU: result.kernelTaskCPU,
            windowServerCPU: result.windowServerCPU,
            notificationCPU: result.notificationCPU,
            spotlightIndexing: result.spotlightIndexing,
            acSleepMinutes: result.acSleepMinutes,
            loginItems: result.loginItems,
            launchAgentCount: result.launchAgentCount,
            topProcesses: result.topProcesses,
            fixes: result.fixes,
            score: score
        )
    }
}
