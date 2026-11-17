import Foundation

/// Pure parsing and labelling helpers used by the probes. Everything here takes
/// text and returns values, so fixtures can exercise it without touching a Mac.
enum ProbeParsers {

    // MARK: - Text helpers

    static func capture(_ pattern: String, _ text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let ns = text as NSString
        guard let match = regex.firstMatch(
            in: text,
            options: [],
            range: NSRange(location: 0, length: ns.length)
        ), match.numberOfRanges > 1 else { return nil }
        return ns.substring(with: match.range(at: 1))
    }

    static func numbers(in text: String) -> [Double] {
        let pattern = "[-+]?[0-9]*\\.?[0-9]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.matches(in: text, range: range).compactMap { match in
            Double((text as NSString).substring(with: match.range))
        }
    }

    // MARK: - CPU and load

    static func loadAverage(_ text: String) -> LoadSample {
        let parts = numbers(in: text)
        return LoadSample(
            load1: parts.count > 0 ? parts[0] : 0,
            load5: parts.count > 1 ? parts[1] : 0,
            load15: parts.count > 2 ? parts[2] : 0
        )
    }

    // MARK: - Memory

    static func freeMemoryPercent(_ memoryPressureOutput: String) -> Double {
        capture("free percentage:\\s*(\\d+)", memoryPressureOutput).flatMap(Double.init) ?? 0
    }

    /// Compressed memory in GB. `page size of 16384 bytes` appears in `vm_stat`
    /// on Apple Silicon; Intel defaults to 4096, so the fallback is a parameter.
    static func compressedGB(vmStat: String, pageSizeFallback: Double = 4096) -> Double {
        let pageSize = capture("page size of (\\d+) bytes", vmStat).flatMap(Double.init) ?? pageSizeFallback
        let pages = capture("Pages occupied by compressor:\\s*(\\d+)", vmStat).flatMap(Double.init) ?? 0
        return pages * pageSize / 1_073_741_824
    }

    static func swapUsedMB(_ sysctlSwapOutput: String) -> Double {
        capture("used = ([0-9.]+)M", sysctlSwapOutput).flatMap(Double.init) ?? 0
    }

    // MARK: - Disk

    /// Parses `df -k` output. `total` and `free` are the 1-based and 3-based
    /// columns of the last row.
    static func disk(_ dfOutput: String) -> DiskSample {
        let line = dfOutput
            .components(separatedBy: "\n")
            .last { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard parts.count >= 4,
              let total = Double(parts[1]),
              let free = Double(parts[3]) else {
            return DiskSample(freeGB: 0, totalGB: 0)
        }
        return DiskSample(freeGB: free / 1_048_576, totalGB: total / 1_048_576)
    }

    // MARK: - Battery

    static func battery(_ ioregOutput: String) -> BatterySample {
        let design = capture("\"DesignCapacity\"\\s*=\\s*(\\d+)", ioregOutput).flatMap(Double.init) ?? 0
        var full = capture("\"FullChargeCapacity\"\\s*=\\s*(\\d+)", ioregOutput).flatMap(Double.init) ?? 0
        if full == 0 {
            full = capture("\"AppleRawMaxCapacity\"\\s*=\\s*(\\d+)", ioregOutput).flatMap(Double.init) ?? 0
        }
        let cycles = Int(capture("\"CycleCount\"\\s*=\\s*(\\d+)", ioregOutput) ?? "0") ?? 0
        let charge = Int(capture("\"CurrentCapacity\"\\s*=\\s*(\\d+)", ioregOutput) ?? "0") ?? 0
        let onAC = (capture("\"ExternalConnected\"\\s*=\\s*(Yes|No)", ioregOutput) ?? "No") == "Yes"
        let charging = (capture("\"IsCharging\"\\s*=\\s*(Yes|No)", ioregOutput) ?? "No") == "Yes"

        let hasBattery = design > 0 && full > 0
        guard hasBattery else { return .none }

        let health = min(100, (full / design) * 100)
        let condition: String
        if health >= 80 && cycles < 1000 {
            condition = "Normal"
        } else {
            condition = "Service Recommended"
        }

        return BatterySample(
            health: health,
            cycles: cycles,
            condition: condition,
            charge: charge,
            charging: charging,
            onAC: onAC,
            hasBattery: true
        )
    }

    // MARK: - Power

    /// AC sleep timer in minutes, read from `pmset -g custom`. Zero means the Mac
    /// never sleeps on power (or the key was missing).
    static func acSleepMinutes(_ pmsetOutput: String) -> Int {
        var inACPower = false
        var minutes = 0
        for raw in pmsetOutput.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("AC Power:") { inACPower = true; continue }
            if line.hasPrefix("Battery Power:") { inACPower = false; continue }
            guard inACPower, line.hasPrefix("sleep") else { continue }
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            if let last = parts.last, let value = Int(last) { minutes = value }
        }
        return minutes
    }

    // MARK: - Processes

    static func topProcesses(_ topOutput: String) -> [TopProcess] {
        let lines = topOutput.components(separatedBy: "\n")
        guard let header = lines.lastIndex(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("PID")
        }) else { return [] }

        var result: [TopProcess] = []
        for line in lines[(header + 1)...] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 3,
                  Int(parts[0]) != nil,
                  let cpu = Double(parts[parts.count - 1]) else { continue }
            let name = parts.dropFirst().dropLast().joined(separator: " ")
            guard !name.isEmpty else { continue }
            result.append(TopProcess(pid: String(parts[0]), name: name, cpu: cpu))
        }
        return result
    }

    // MARK: - Spotlight

    /// Returns true if Spotlight worker processes (mds, mds_stores, mdworker) are
    /// actively consuming CPU above the threshold (default 10%), indicating active
    /// background indexing rather than simple configuration status.
    static func isSpotlightIndexing(cpu: Double, threshold: Double = 10.0) -> Bool {
        cpu >= threshold
    }

    /// Legacy helper for mdutil output parsing kept for backward-compatibility.
    static func spotlightIndexing(_ mdutilOutput: String) -> Bool {
        mdutilOutput.contains("Indexing enabled") && !mdutilOutput.contains("disabled")
    }

    /// Sum of CPU for every process whose name matches exactly (case-insensitive).
    /// `top` lists each worker separately, so Spotlight and friends can appear
    /// several times.
    static func totalCPU(of names: [String], in top: [TopProcess]) -> Double {
        let wanted = Set(names.map { $0.lowercased() })
        return top
            .filter { wanted.contains($0.name.lowercased()) }
            .reduce(0) { $0 + $1.cpu }
    }

    // MARK: - Time Machine

    /// `tmutil destinationinfo` prints one block per destination. Any block with
    /// a `Kind` or `Mount Point` means a backup disk is configured.
    static func hasTimeMachineDestination(_ text: String) -> Bool {
        let lower = text.lowercased()
        guard !lower.contains("no destinations configured") else { return false }
        return lower.contains("kind") || lower.contains("mount point")
    }

    /// `tmutil latestbackup` prints the snapshot path, which ends in a timestamp
    /// such as `2026-11-16-215930` (sometimes followed by `.inProgress`).
    static func latestBackupDate(_ text: String, timeZone: TimeZone = .current) -> Date? {
        guard let stamp = capture("(\\d{4}-\\d{2}-\\d{2}-\\d{6})", text) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.date(from: stamp)
    }

    /// Whole days between a backup date and `now`, counted by calendar day so a
    /// backup at 23:50 yesterday is "1 day ago" rather than "0".
    static func daysSince(
        _ date: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard let date else { return nil }
        let from = calendar.startOfDay(for: date)
        let to = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }

    // MARK: - MDM

    /// Parses `profiles status -type enrollment`. Both the older DEP line and the
    /// newer "MDM enrollment:" line count, and "No" never does.
    static func mdmEnrolled(_ text: String) -> Bool {
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces).lowercased()
            if line.hasPrefix("mdm enrollment:") {
                return line.contains("yes")
            }
            if line.hasPrefix("enrolled via dep:") {
                return line.contains("yes")
            }
        }
        return false
    }

    // MARK: - SMB

    /// Mount points from `mount` lines that use `smbfs`, e.g.
    /// `//user@host/share on /Volumes/share (smbfs, nodev, ...)`.
    static func smbMounts(_ text: String) -> [String] {
        text.components(separatedBy: "\n").compactMap { line in
            guard line.contains("(smbfs"), let onRange = line.range(of: " on ") else { return nil }
            let rest = line[onRange.upperBound...]
            guard let end = rest.range(of: " (smbfs") else { return nil }
            let path = String(rest[..<end.lowerBound]).trimmingCharacters(in: .whitespaces)
            return path.isEmpty ? nil : path
        }
    }

    // MARK: - Uptime

    static func bootSeconds(_ sysctlBoottimeOutput: String) -> Double {
        capture("sec = (\\d+)", sysctlBoottimeOutput).flatMap(Double.init) ?? 0
    }

    static func uptime(bootSeconds: Double, now: Date) -> String {
        guard bootSeconds > 0 else { return "—" }
        let seconds = max(0, Int(now.timeIntervalSince1970 - bootSeconds))
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    // MARK: - Homebrew services

    /// Reads `brew services list --json` first and falls back to the table.
    /// Only services in the `started` state are returned.
    static func brewServices(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("["),
           let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           let items = object as? [[String: Any]] {
            return items.compactMap { item in
                guard let name = item["name"] as? String else { return nil }
                let status = (item["status"] as? String)?.lowercased()
                return status == "started" ? name : nil
            }
        }

        return text
            .components(separatedBy: "\n")
            .dropFirst()
            .compactMap { line in
                let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                guard parts.count >= 2, parts[1].lowercased() == "started" else { return nil }
                return String(parts[0])
            }
    }

    // MARK: - launchctl

    /// Parses `launchctl list` into (pid, label) pairs. A `-` pid means the job
    /// is loaded but not running.
    static func launchctlEntries(_ text: String) -> [(pid: String, label: String)] {
        text
            .components(separatedBy: "\n")
            .dropFirst()
            .compactMap { line in
                let parts = line.split(omittingEmptySubsequences: true, whereSeparator: {
                    $0 == "\t" || $0 == " "
                })
                guard parts.count >= 3 else { return nil }
                return (pid: String(parts[0]), label: String(parts[parts.count - 1]))
            }
    }

    /// Labels MacPulse must never offer to disable, even when they are busy.
    /// This includes system daemons, MacPulse itself, and running GUI apps tracked
    /// by launchd under synthetic LaunchServices labels (e.g. application.*).
    static func isProtectedLabel(_ label: String) -> Bool {
        let lower = label.lowercased()
        return lower.hasPrefix("com.apple.")
            || lower.hasPrefix("com.macpulse.")
            || lower.hasPrefix("homebrew.")
            || lower.hasPrefix("com.openssh.")
            || lower.hasPrefix("org.openbsd.")
            || lower.hasPrefix("application.")
            || lower.hasPrefix("uikitapplication.")
            || lower.hasPrefix("xpc.service.")
            || lower.hasPrefix("user.")
            || lower.hasPrefix("service.")
            || lower.contains(".shipit")
    }

    static let vendorHints: [String] = [
        "docker", "vmware", "parallels", "virtualbox", "zerotier", "teamviewer",
        "logmein", "huion", "wacom", "razer", "logi", "logitech", "nordvpn",
        "expressvpn", "surfshark", "cisco", "anydesk", "parsec", "splashtop",
        "dropbox", "google", "microsoft", "jamf", "oracle", "tencent", "alipay",
        "baidu", "zoom", "box", "amazon", "obs", "elgato", "citrix", "realvnc"
    ]

    static func isVendorLabel(_ label: String) -> Bool {
        guard !isProtectedLabel(label) else { return false }
        let lower = label.lowercased()
        return vendorHints.contains { lower.contains($0) }
    }

    static func friendlyHelperName(_ label: String) -> String {
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

    struct HelperCandidate: Equatable {
        let label: String
        let busyCPU: Double
    }

    /// Decides which launch agents deserve a suggestion: vendor-labelled ones
    /// plus any non-Apple agent that is actually burning CPU. Unknown quiet
    /// agents are deliberately left alone.
    static func helperCandidates(
        entries: [(pid: String, label: String)],
        cpuByPID: [String: Double],
        busyThreshold: Double = 8,
        limit: Int = 8
    ) -> [HelperCandidate] {
        var seen = Set<String>()
        var result: [HelperCandidate] = []
        for entry in entries {
            let label = entry.label
            guard !label.isEmpty,
                  !seen.contains(label),
                  !isProtectedLabel(label) else { continue }

            let cpu = entry.pid == "-" ? 0 : (cpuByPID[entry.pid] ?? 0)
            guard isVendorLabel(label) || cpu >= busyThreshold else { continue }

            seen.insert(label)
            result.append(HelperCandidate(label: label, busyCPU: cpu))
            if result.count >= limit { break }
        }
        return result
    }

    // MARK: - Sleep assertions and peripherals

    static func sleepAssertions(_ output: String) -> SleepAssertionSample {
        var assertions: [SleepAssertion] = []
        var preventSystemSleep = false
        var preventDisplaySleep = false

        if let val = capture("PreventUserIdleSystemSleep\\s+(\\d+)", output), let n = Int(val), n > 0 {
            preventSystemSleep = true
        }
        if let val = capture("PreventUserIdleDisplaySleep\\s+(\\d+)", output), let n = Int(val), n > 0 {
            preventDisplaySleep = true
        }

        let section = output.components(separatedBy: "Listed by owning process:").last ?? ""
        let lines = section.components(separatedBy: "\n")

        let pattern = "^\\s*pid\\s+(\\d+)\\(([^)]+)\\):\\s*\\[[^\\]]+\\]\\s*(?:[\\d:]+\\s+)?([A-Za-z0-9_-]+)(?:\\s+named:\\s*\"?([^\"\\n]+)\"?)?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return SleepAssertionSample(assertions: [], preventSystemSleep: preventSystemSleep, preventDisplaySleep: preventDisplaySleep)
        }

        for line in lines {
            let ns = line as NSString
            guard let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: ns.length)),
                  match.numberOfRanges > 3 else {
                continue
            }
            let pidStr = ns.substring(with: match.range(at: 1))
            guard let pid = Int(pidStr) else { continue }
            let process = ns.substring(with: match.range(at: 2))
            let assertionType = ns.substring(with: match.range(at: 3))
            var name = ""
            if match.numberOfRanges > 4 && match.range(at: 4).location != NSNotFound {
                name = ns.substring(with: match.range(at: 4))
            }
            assertions.append(SleepAssertion(
                pid: pid,
                process: process,
                assertionType: assertionType,
                name: name
            ))
        }

        return SleepAssertionSample(
            assertions: assertions,
            preventSystemSleep: preventSystemSleep,
            preventDisplaySleep: preventDisplaySleep
        )
    }

    static func peripheralBatteries(_ ioregOutput: String) -> [PeripheralBattery] {
        var results: [PeripheralBattery] = []
        let blocks = ioregOutput.components(separatedBy: "}")
        for block in blocks {
            guard let name = capture("\"(?:Product|DeviceProduct)\"\\s*=\\s*\"([^\"]+)\"", block),
                  let percentStr = capture("\"BatteryPercent\"\\s*=\\s*(\\d+)", block),
                  let percent = Int(percentStr) else {
                continue
            }
            if !results.contains(where: { $0.name == name }) {
                results.append(PeripheralBattery(name: name, percent: percent))
            }
        }
        return results
    }

    // MARK: - Naming

    static func friendlyModel(_ identifier: String, chip: String) -> String {
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
}
