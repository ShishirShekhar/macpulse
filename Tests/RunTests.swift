import Foundation

// Test runner for MacPulse engine: parsers, rules, and scoring.
// Runs headless with Command Line Tools only.

@main
struct RunTests {
    static var passed = 0
    static var failed = 0

    static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: String = #file, line: Int = #line) {
        if actual == expected {
            passed += 1
        } else {
            failed += 1
            print("❌ FAIL [\(line)]: \(message) — Expected '\(expected)', got '\(actual)'")
        }
    }

    static func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        if condition {
            passed += 1
        } else {
            failed += 1
            print("❌ FAIL [\(line)]: \(message)")
        }
    }

    static func assertFalse(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        assertTrue(!condition, message, file: file, line: line)
    }

    static func readFixture(_ name: String) -> String {
        let scriptPath = URL(fileURLWithPath: #file)
        let fixturesDir = scriptPath.deletingLastPathComponent().appendingPathComponent("Fixtures")
        let fileURL = fixturesDir.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: fileURL),
              let str = String(data: data, encoding: .utf8) else {
            fatalError("Could not read fixture: \(name) at \(fileURL.path)")
        }
        return str
    }

    static func main() {
        print("=== Running MacPulse Test Suite ===")

        // MARK: - 1. Parser Tests

        print("▸ Testing ProbeParsers…")

        // Load average
        let loadText = "1.50 2.25 0.75"
        let load = ProbeParsers.loadAverage(loadText)
        assertEqual(load.load1, 1.50, "load1 parsed")
        assertEqual(load.load5, 2.25, "load5 parsed")
        assertEqual(load.load15, 0.75, "load15 parsed")

        // Memory
        let memPressure = "The system has 40% memory available\nfree percentage: 35"
        assertEqual(ProbeParsers.freeMemoryPercent(memPressure), 35.0, "Free memory percent")

        let vmStatArm = readFixture("vm_stat_arm64.txt")
        let compressedArm = ProbeParsers.compressedGB(vmStat: vmStatArm)
        assertEqual(compressedArm, 1.0, "Compressed RAM Apple Silicon (16k page)")

        let vmStatIntel = readFixture("vm_stat_intel.txt")
        let compressedIntel = ProbeParsers.compressedGB(vmStat: vmStatIntel, pageSizeFallback: 4096)
        assertEqual(compressedIntel, 2.0, "Compressed RAM Intel (4k page)")

        let swapText = readFixture("sysctl_swap.txt")
        assertEqual(ProbeParsers.swapUsedMB(swapText), 1250.5, "Swap used MB")

        // Disk
        let dfText = readFixture("df_k.txt")
        let disk = ProbeParsers.disk(dfText)
        assertTrue(disk.freeGB > 114 && disk.freeGB < 116, "Disk free GB ~114.9 GB")
        assertTrue(disk.totalGB > 232 && disk.totalGB < 234, "Disk total GB ~232.9 GB")

        // Battery
        let batNormal = ProbeParsers.battery(readFixture("ioreg_battery_normal.txt"))
        assertTrue(batNormal.hasBattery, "Normal battery detected")
        assertEqual(batNormal.condition, "Normal", "Battery condition Normal")
        assertEqual(batNormal.cycles, 120, "Battery cycle count")
        assertEqual(batNormal.health, 96.0, "Battery health 96%")

        let batService = ProbeParsers.battery(readFixture("ioreg_battery_service.txt"))
        assertTrue(batService.hasBattery, "Service battery detected")
        assertEqual(batService.condition, "Service Recommended", "Battery condition Service")
        assertEqual(batService.cycles, 1150, "Battery high cycles")
        assertEqual(batService.health, 52.0, "Battery health 52%")

        let batNone = ProbeParsers.battery(readFixture("ioreg_nobattery.txt"))
        assertFalse(batNone.hasBattery, "No battery detected for desktop")
        assertEqual(batNone.condition, "No battery", "Condition is No battery")

        // Power
        let pmset = readFixture("pmset_custom.txt")
        assertEqual(ProbeParsers.acSleepMinutes(pmset), 3, "AC sleep minutes parsed from custom output")

        // Processes
        let topOutput = readFixture("top.txt")
        let processes = ProbeParsers.topProcesses(topOutput)
        assertTrue(processes.count >= 6, "Parsed top processes")
        if let kernel = processes.first(where: { $0.name == "kernel_task" }) {
            assertEqual(kernel.cpu, 18.5, "kernel_task CPU")
        } else {
            assertTrue(false, "kernel_task found in top output")
        }

        // Uptime
        let bootText = readFixture("sysctl_boottime.txt")
        let bootSec = ProbeParsers.bootSeconds(bootText)
        assertEqual(bootSec, 1700000000.0, "Boot seconds parsed")
        let now = Date(timeIntervalSince1970: 1700000000 + 86400 * 3 + 3600 * 5)
        assertEqual(ProbeParsers.uptime(bootSeconds: bootSec, now: now), "3d 5h", "Uptime formatted")

        // Homebrew services
        let brewJson = readFixture("brew_services.json")
        let servicesFromJson = ProbeParsers.brewServices(brewJson)
        assertEqual(servicesFromJson, ["postgresql@14", "nginx"], "Started brew services from JSON")

        let brewTxt = readFixture("brew_services.txt")
        let servicesFromTxt = ProbeParsers.brewServices(brewTxt)
        assertEqual(servicesFromTxt, ["postgresql@14", "nginx"], "Started brew services from text")

        // Helpers
        let launchctl = readFixture("launchctl_list.txt")
        let entries = ProbeParsers.launchctlEntries(launchctl)
        assertTrue(entries.contains { $0.label == "com.docker.helper" && $0.pid == "1234" }, "launchctl entry parsed")

        assertTrue(ProbeParsers.isProtectedLabel("com.apple.Safari"), "Apple label protected")
        assertTrue(ProbeParsers.isProtectedLabel("com.macpulse.daily"), "MacPulse label protected")
        assertTrue(ProbeParsers.isProtectedLabel("homebrew.mxcl.postgresql"), "Homebrew label protected")
        assertFalse(ProbeParsers.isProtectedLabel("com.docker.helper"), "Docker label not protected")

        assertTrue(ProbeParsers.isVendorLabel("com.docker.helper"), "Docker is vendor label")
        assertTrue(ProbeParsers.isVendorLabel("com.nordvpn.osx.helper"), "NordVPN is vendor label")
        assertFalse(ProbeParsers.isVendorLabel("com.mycustomapp.worker"), "Custom app not vendor label")

        assertEqual(ProbeParsers.friendlyHelperName("com.docker.helper"), "Docker", "Friendly helper name Docker")
        assertEqual(ProbeParsers.friendlyHelperName("com.nordvpn.osx.helper"), "NordVPN", "Friendly helper name NordVPN")

        let candidates = ProbeParsers.helperCandidates(
            entries: entries,
            cpuByPID: ["1234": 5.0, "9012": 15.0]
        )
        assertTrue(candidates.contains { $0.label == "com.docker.helper" }, "Docker candidate included by vendor match")
        assertTrue(candidates.contains { $0.label == "com.nordvpn.osx.helper" }, "NordVPN candidate included")
        assertFalse(candidates.contains { $0.label.contains("apple") }, "Apple never in helper candidates")

        // Model naming
        assertEqual(ProbeParsers.friendlyModel("MacBookAir10,1", chip: "Apple M1"), "MacBook Air (M1, 2020) · Apple M1", "Friendly model M1 Air")
        assertEqual(ProbeParsers.friendlyModel("Macmini9,1", chip: "Apple M1"), "Mac mini (M1, 2020) · Apple M1", "Friendly model M1 Mac mini")

        // MARK: - 2. Rules Tests

        print("▸ Testing Rules…")

        let laptopProfile = DeviceProfile(
            modelIdentifier: "MacBookAir10,1",
            chip: "Apple M1",
            cores: 8,
            performanceCores: 4,
            efficiencyCores: 4,
            isAppleSilicon: true,
            isLaptop: true,
            hasBattery: true,
            osMajor: 14,
            ramGB: 16
        )

        let desktopProfile = DeviceProfile(
            modelIdentifier: "Mac13,1",
            chip: "Apple M1 Max",
            cores: 10,
            performanceCores: 8,
            efficiencyCores: 2,
            isAppleSilicon: true,
            isLaptop: false,
            hasBattery: false,
            osMajor: 14,
            ramGB: 32
        )

        // Battery rule on laptop vs desktop
        let laptopBadBatteryContext = RuleContext(
            profile: laptopProfile,
            interactive: true,
            notificationCPU: 0,
            acSleepMinutes: 10,
            loginItems: [],
            memFreePct: 50,
            swapUsedMB: 0,
            diskFreeGB: 50,
            diskFreePct: 50,
            windowServerCPU: 10,
            kernelTaskCPU: 5,
            batteryHealthPct: 65,
            batteryCondition: "Service Recommended",
            batteryCycles: 1100,
            brewServices: [],
            helpers: [],
            heavyApps: []
        )
        let laptopFixes = Rules.build(laptopBadBatteryContext)
        assertTrue(laptopFixes.contains { $0.id == "battery" }, "Battery fix suggested for degraded laptop battery")

        let desktopBadBatteryContext = RuleContext(
            profile: desktopProfile,
            interactive: true,
            notificationCPU: 0,
            acSleepMinutes: 10,
            loginItems: [],
            memFreePct: 50,
            swapUsedMB: 0,
            diskFreeGB: 50,
            diskFreePct: 50,
            windowServerCPU: 10,
            kernelTaskCPU: 5,
            batteryHealthPct: 0,
            batteryCondition: "No battery",
            batteryCycles: 0,
            brewServices: [],
            helpers: [],
            heavyApps: []
        )
        let desktopFixes = Rules.build(desktopBadBatteryContext)
        assertFalse(desktopFixes.contains { $0.id == "battery" }, "Desktop with no battery never receives battery advice")

        // Purge rule
        var purgeContext = desktopBadBatteryContext
        purgeContext.memFreePct = 5
        purgeContext.swapUsedMB = 1500
        let purgeFixes = Rules.build(purgeContext)
        assertTrue(purgeFixes.contains { $0.id == "purge" }, "Purge RAM fix suggested when free RAM < 10% and swap > 1GB")

        // Notification rule
        var notifContext = desktopBadBatteryContext
        notifContext.notificationCPU = 12.0
        let notifFixes = Rules.build(notifContext)
        assertTrue(notifFixes.contains { $0.id == "notifications" }, "NotificationCenter restart suggested when CPU > 5%")

        // Sleep rule
        var sleepContext = desktopBadBatteryContext
        sleepContext.acSleepMinutes = 3
        let sleepFixes = Rules.build(sleepContext)
        assertTrue(sleepFixes.contains { $0.id == "sleep" }, "Sleep timer fix suggested when AC sleep is 3 min")

        // WindowServer rule: interactive vs headless
        var wsInteractiveContext = desktopBadBatteryContext
        wsInteractiveContext.windowServerCPU = 75.0
        wsInteractiveContext.interactive = true
        assertTrue(Rules.build(wsInteractiveContext).contains { $0.id == "windowserver" }, "WindowServer advice in interactive scan")

        var wsHeadlessContext = wsInteractiveContext
        wsHeadlessContext.interactive = false
        assertFalse(Rules.build(wsHeadlessContext).contains { $0.id == "windowserver" }, "WindowServer advice NOT triggered in headless scan")

        // Generic detectors: heavy apps, brew services, helpers
        var genericContext = desktopBadBatteryContext
        genericContext.heavyApps = [HeavyApp(name: "Blender", bundleID: "org.blender.app", cpu: 85.0, pid: 4567)]
        genericContext.brewServices = ["postgresql@14"]
        genericContext.helpers = [HelperService(label: "com.docker.helper", friendlyName: "Docker", admin: false, plistPath: nil)]

        let genericFixes = Rules.build(genericContext)
        assertTrue(genericFixes.contains { $0.id == "quit-org.blender.app" }, "Quit heavy app suggested")
        assertTrue(genericFixes.contains { $0.id == "brew-postgresql@14" }, "Stop brew service suggested")
        assertTrue(genericFixes.contains { $0.id == "helper-com.docker.helper" }, "Disable helper suggested")

        // MARK: - 3. Scoring Tests

        print("▸ Testing Scoring…")

        let baselineInput = ScoreInput(
            cpuCores: 8,
            load1: 1.0,
            memFreePct: 40,
            swapUsedMB: 100,
            diskFreePct: 40,
            hasBattery: false,
            batteryHealthPct: 0,
            batteryCondition: "No battery",
            kernelTaskCPU: 5,
            notificationCPU: 1,
            acSleepMinutes: 15,
            launchAgentCount: 4,
            windowServerCPU: 15,
            interactive: true
        )

        let cleanResult = Scoring.evaluate(baselineInput)
        assertEqual(cleanResult.score, 100, "Clean machine scores 100")
        assertEqual(cleanResult.subscores.reduce(0) { $0 + $1.points }, 0, "No deducted points")

        // Heavy load test
        var highLoadInput = baselineInput
        highLoadInput.load1 = 15.0 // > 8 * 1.5 = 12
        let highLoadResult = Scoring.evaluate(highLoadInput)
        assertEqual(highLoadResult.score, 80, "Heavy CPU load loses 20 points")
        assertEqual(highLoadResult.subscores.first { $0.id == "cpu" }?.points, 20, "CPU subscore reflects 20 pt loss")

        // Memory pressure
        var memPressureInput = baselineInput
        memPressureInput.memFreePct = 8.0
        memPressureInput.swapUsedMB = 1500
        let memResult = Scoring.evaluate(memPressureInput)
        assertEqual(memResult.score, 85, "Memory pressure loses 15 points")

        // Low storage
        var lowStorageInput = baselineInput
        lowStorageInput.diskFreePct = 8.0
        let lowStorageResult = Scoring.evaluate(lowStorageInput)
        assertEqual(lowStorageResult.score, 85, "Low disk space loses 15 points")

        // Battery penalties: only on battery machines
        var degradedBatteryInput = baselineInput
        degradedBatteryInput.hasBattery = true
        degradedBatteryInput.batteryHealthPct = 50.0
        degradedBatteryInput.batteryCondition = "Service Recommended"
        let degradedBatResult = Scoring.evaluate(degradedBatteryInput)
        assertEqual(degradedBatResult.score, 75, "Failing battery loses 25 points on laptop")

        var desktopNoBatteryInput = baselineInput
        desktopNoBatteryInput.hasBattery = false
        desktopNoBatteryInput.batteryHealthPct = 0
        desktopNoBatteryInput.batteryCondition = "No battery"
        let desktopBatResult = Scoring.evaluate(desktopNoBatteryInput)
        assertEqual(desktopBatResult.score, 100, "Desktop with no battery is not penalized")

        // WindowServer: only interactive
        var highWSInput = baselineInput
        highWSInput.windowServerCPU = 60.0
        highWSInput.interactive = true
        assertEqual(Scoring.evaluate(highWSInput).score, 95, "Busy WindowServer loses 5 points interactively")

        highWSInput.interactive = false
        assertEqual(Scoring.evaluate(highWSInput).score, 100, "Busy WindowServer ignored in headless scan")

        // Multiple compounding penalties
        var compoundedInput = baselineInput
        compoundedInput.load1 = 20.0        // -20
        compoundedInput.memFreePct = 5.0    // -15
        compoundedInput.diskFreePct = 5.0   // -15
        compoundedInput.kernelTaskCPU = 40  // -15
        let compoundedResult = Scoring.evaluate(compoundedInput)
        assertEqual(compoundedResult.score, 35, "Compounded penalties add up (100 - 65 = 35)")

        // Summary
        print("\n===============================")
        print("Passed: \(passed)")
        print("Failed: \(failed)")
        print("===============================")

        if failed > 0 {
            exit(1)
        } else {
            print("✅ All tests passed!")
            exit(0)
        }
    }
}

