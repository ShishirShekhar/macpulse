import Foundation

/// Orchestrates one scan: probes read the machine, rules decide what to offer,
/// scoring turns the measurements into a number and a breakdown.
enum SystemCheck {
    // MARK: - Public

    static func collect(interactive: Bool = true, now: Date = Date()) -> CheckResult {
        let cpu = CPUProbe.sample()
        let memory = MemoryProbe.sample()
        let disk = DiskProbe.sample()
        let battery = BatteryProbe.sample()
        let system = SystemProbe.sample(now: now)
        let display = DisplayProbe.sample()
        let backup = BackupProbe.sample()
        let management = ManagementProbe.sample()

        // Headless scans cannot ask for Automation permission, so the startup
        // probe keeps the cached login items from the previous scan.
        let startup = StartupProbe.sample(
            interactive: interactive,
            cachedLoginItems: load()?.loginItems ?? [],
            top: display.top
        )

        let profile = DeviceProfile(
            modelIdentifier: cpu.modelIdentifier,
            chip: cpu.chip,
            cores: cpu.cores,
            performanceCores: cpu.performanceCores,
            efficiencyCores: cpu.efficiencyCores,
            isAppleSilicon: cpu.isAppleSilicon,
            isLaptop: cpu.modelIdentifier.hasPrefix("MacBook"),
            hasBattery: battery.hasBattery,
            osMajor: system.osMajor,
            ramGB: memory.totalGB
        )

        let context = RuleContext(
            profile: profile,
            interactive: interactive,
            notificationCPU: display.notificationCPU,
            acSleepMinutes: system.acSleepMinutes,
            loginItems: startup.loginItems,
            memFreePct: memory.freePercent,
            swapUsedMB: memory.swapUsedMB,
            diskFreeGB: disk.freeGB,
            diskFreePct: disk.freePercent,
            windowServerCPU: display.windowServerCPU,
            kernelTaskCPU: display.kernelTaskCPU,
            batteryHealthPct: battery.health,
            batteryCondition: battery.condition,
            batteryCycles: battery.cycles,
            brewServices: startup.brewServices,
            helpers: startup.helpers,
            heavyApps: display.heavyApps,
            hasBackupDestination: backup.hasDestination,
            lastBackupDays: ProbeParsers.daysSince(backup.lastBackup, now: now),
            backupdCPU: display.backupdCPU,
            spotlightCPU: display.spotlightCPU,
            dnsCPU: display.dnsCPU,
            smbCPU: display.smbCPU,
            smbMounts: display.smbMounts,
            mdmEnrolled: management.mdmEnrolled
        )
        let fixes = Rules.build(context)

        let scoring = Scoring.evaluate(ScoreInput(
            cpuCores: cpu.cores,
            load1: cpu.load.load1,
            memFreePct: memory.freePercent,
            swapUsedMB: memory.swapUsedMB,
            diskFreePct: disk.freePercent,
            hasBattery: battery.hasBattery,
            batteryHealthPct: battery.health,
            batteryCondition: battery.condition,
            kernelTaskCPU: display.kernelTaskCPU,
            notificationCPU: display.notificationCPU,
            acSleepMinutes: system.acSleepMinutes,
            launchAgentCount: startup.launchAgentCount,
            windowServerCPU: display.windowServerCPU,
            interactive: interactive
        ))

        return CheckResult(
            date: now,
            model: cpu.modelIdentifier,
            modelName: ProbeParsers.friendlyModel(cpu.modelIdentifier, chip: cpu.chip),
            osVersion: system.osVersion,
            uptime: system.uptime,
            cpuCores: cpu.cores,
            load1: cpu.load.load1,
            load5: cpu.load.load5,
            load15: cpu.load.load15,
            memTotalGB: memory.totalGB,
            memFreePct: memory.freePercent,
            memCompressedGB: memory.compressedGB,
            swapUsedMB: memory.swapUsedMB,
            diskFreeGB: disk.freeGB,
            diskTotalGB: disk.totalGB,
            batteryHealthPct: battery.health,
            batteryCycles: battery.cycles,
            batteryCondition: battery.condition,
            batteryCharge: battery.charge,
            charging: battery.charging,
            onAC: battery.onAC,
            kernelTaskCPU: display.kernelTaskCPU,
            windowServerCPU: display.windowServerCPU,
            notificationCPU: display.notificationCPU,
            spotlightIndexing: display.spotlightIndexing,
            acSleepMinutes: system.acSleepMinutes,
            loginItems: startup.loginItems,
            launchAgentCount: startup.launchAgentCount,
            topProcesses: Array(display.top.prefix(8)),
            fixes: fixes,
            score: scoring.score,
            subscores: scoring.subscores,
            profile: profile
        )
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

    /// Removes the cached scan. User preferences are reset separately.
    static func clearCache() {
        try? FileManager.default.removeItem(at: storeURL)
    }
}
