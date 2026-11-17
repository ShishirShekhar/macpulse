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
        assertTrue(ProbeParsers.isProtectedLabel("application.com.microsoft.VSCode.23798302.23798915"), "Running GUI app protected")
        assertTrue(ProbeParsers.isProtectedLabel("application.net.whatsapp.WhatsApp.123"), "Running WhatsApp protected")
        assertTrue(ProbeParsers.isProtectedLabel("com.microsoft.VSCode.ShipIt"), "ShipIt updater protected")
        assertTrue(ProbeParsers.isProtectedLabel("uikitapplication.com.foo.bar"), "UIKitApplication label protected")
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
        assertFalse(candidates.contains { $0.label.contains("application.") }, "Running application never in helper candidates")

        // Model naming
        assertEqual(ProbeParsers.friendlyModel("MacBookAir10,1", chip: "Apple M1"), "MacBook Air (M1, 2020) · Apple M1", "Friendly model M1 Air")
        assertEqual(ProbeParsers.friendlyModel("Macmini9,1", chip: "Apple M1"), "Mac mini (M1, 2020) · Apple M1", "Friendly model M1 Mac mini")

        // Time Machine destination and staleness
        assertTrue(
            ProbeParsers.hasTimeMachineDestination(readFixture("tmutil_destination.txt")),
            "Time Machine destination detected"
        )
        assertFalse(
            ProbeParsers.hasTimeMachineDestination(readFixture("tmutil_nodestination.txt")),
            "No Time Machine destination detected"
        )

        let utc = TimeZone(identifier: "UTC")!
        let backupDate = ProbeParsers.latestBackupDate(
            readFixture("tmutil_latestbackup.txt"),
            timeZone: utc
        )
        assertTrue(backupDate != nil, "Time Machine snapshot timestamp parsed")
        if let backupDate {
            var backupCalendar = Calendar(identifier: .gregorian)
            backupCalendar.timeZone = utc
            assertEqual(
                ProbeParsers.daysSince(
                    backupDate,
                    now: backupDate.addingTimeInterval(86400 * 3 + 600),
                    calendar: backupCalendar
                ),
                3,
                "Days since backup counts whole calendar days"
            )
            assertEqual(
                ProbeParsers.daysSince(nil, now: backupDate),
                nil,
                "No backup date yields no age"
            )
        }

        // MDM enrollment
        assertTrue(
            ProbeParsers.mdmEnrolled(readFixture("profiles_enrolled.txt")),
            "MDM enrollment detected"
        )
        assertFalse(
            ProbeParsers.mdmEnrolled(readFixture("profiles_unenrolled.txt")),
            "Unmanaged Mac is not flagged"
        )
        assertFalse(ProbeParsers.mdmEnrolled(""), "Empty enrollment output is not flagged")

        // SMB mounts
        assertEqual(
            ProbeParsers.smbMounts(readFixture("mount_smb.txt")),
            ["/Volumes/Media"],
            "SMB mount point parsed"
        )
        assertEqual(
            ProbeParsers.smbMounts("devfs on /dev (devfs, local, nobrowse)"),
            [],
            "Local mounts are not SMB"
        )

        // Per-process aggregates
        let aggregateProcesses = [
            TopProcess(pid: "1", name: "mds", cpu: 12.5),
            TopProcess(pid: "2", name: "MDS_Stores", cpu: 4.0),
            TopProcess(pid: "3", name: "mds", cpu: 3.5),
            TopProcess(pid: "4", name: "Safari", cpu: 50)
        ]
        assertEqual(
            ProbeParsers.totalCPU(of: ["mds", "mds_stores"], in: aggregateProcesses),
            20.0,
            "CPU aggregate sums duplicate and case-insensitive names"
        )
        assertEqual(
            ProbeParsers.totalCPU(of: ["backupd"], in: aggregateProcesses),
            0,
            "Missing process contributes no CPU"
        )

        // Power and sleep assertions
        let assertionsSample = ProbeParsers.sleepAssertions(readFixture("pmset_assertions.txt"))
        assertTrue(assertionsSample.preventSystemSleep, "System sleep prevention parsed from pmset")
        assertFalse(assertionsSample.preventDisplaySleep, "Display sleep prevention is false")
        assertEqual(assertionsSample.assertions.count, 2, "Found 2 owning processes")
        assertEqual(assertionsSample.assertions[0].pid, 12345, "caffeinate PID parsed")
        assertEqual(assertionsSample.assertions[0].process, "caffeinate", "caffeinate process name parsed")
        assertEqual(assertionsSample.assertions[0].assertionType, "PreventUserIdleSystemSleep", "Assertion type parsed")
        assertEqual(assertionsSample.assertions[0].name, "caffeinate", "Assertion name parsed")
        assertEqual(assertionsSample.assertions[1].pid, 175, "coreaudiod PID parsed")
        assertEqual(assertionsSample.assertions[1].process, "coreaudiod", "coreaudiod process name parsed")

        let emptyAssertions = ProbeParsers.sleepAssertions("2026-11-17 17:49:09 +0530 \nNo assertions.\nNo kernel assertions.\n")
        assertFalse(emptyAssertions.preventSystemSleep, "No system sleep prevention on idle machine")
        assertEqual(emptyAssertions.assertions.count, 0, "No assertions parsed from empty output")

        // Peripheral batteries
        let peripherals = ProbeParsers.peripheralBatteries(readFixture("ioreg_peripherals.txt"))
        assertEqual(peripherals.count, 2, "Found 2 peripherals in fixture")
        assertEqual(peripherals[0].name, "Magic Mouse", "Magic Mouse name parsed")
        assertEqual(peripherals[0].percent, 85, "Magic Mouse 85% battery parsed")
        assertEqual(peripherals[1].name, "Magic Keyboard", "Magic Keyboard name parsed")
        assertEqual(peripherals[1].percent, 15, "Magic Keyboard 15% battery parsed")
        assertEqual(ProbeParsers.peripheralBatteries("").count, 0, "Empty ioreg output yields no peripherals")

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
        genericContext.helpers = [HelperService(label: "com.docker.helper", friendlyName: "Docker", admin: false, plistPath: "/Library/LaunchAgents/com.docker.helper.plist")]

        let genericFixes = Rules.build(genericContext)
        assertTrue(genericFixes.contains { $0.id == "quit-org.blender.app" }, "Quit heavy app suggested")
        assertTrue(genericFixes.contains { $0.id == "brew-postgresql@14" }, "Stop brew service suggested")
        assertTrue(genericFixes.contains { $0.id == "helper-com.docker.helper" }, "Disable helper suggested")

        // Phase 5: Time Machine
        var noBackupContext = desktopBadBatteryContext
        noBackupContext.hasBackupDestination = false
        let noBackupFixes = Rules.build(noBackupContext)
        assertTrue(noBackupFixes.contains { $0.id == "timemachine-none" }, "Missing backup disk is reported")
        assertTrue(
            noBackupFixes.first { $0.id == "timemachine-none" }?.command.isEmpty == true,
            "Backup setup is advice only"
        )

        var staleBackupContext = desktopBadBatteryContext
        staleBackupContext.hasBackupDestination = true
        staleBackupContext.lastBackupDays = 12
        let staleBackupFixes = Rules.build(staleBackupContext)
        assertTrue(staleBackupFixes.contains { $0.id == "timemachine-stale" }, "Stale backup is flagged")
        assertEqual(
            staleBackupFixes.first { $0.id == "timemachine-stale" }?.undoCommand ?? "",
            "tmutil stopbackup",
            "Start-backup fix is reversible"
        )

        var freshBackupContext = desktopBadBatteryContext
        freshBackupContext.hasBackupDestination = true
        freshBackupContext.lastBackupDays = 1
        assertFalse(
            Rules.build(freshBackupContext).contains { $0.id == "timemachine-stale" },
            "Recent backup is not flagged"
        )

        var runningBackupContext = desktopBadBatteryContext
        runningBackupContext.backupdCPU = 40
        let runningBackupFixes = Rules.build(runningBackupContext)
        assertTrue(runningBackupFixes.contains { $0.id == "backup" }, "Active backup is explained")
        assertTrue(
            runningBackupFixes.first { $0.id == "backup" }?.command.isEmpty == true,
            "Active backup is never stopped automatically"
        )

        // Phase 5: Spotlight, DNS, SMB and MDM
        var spotlightContext = desktopBadBatteryContext
        spotlightContext.spotlightCPU = 35
        assertTrue(
            Rules.build(spotlightContext).contains { $0.id == "spotlight" },
            "Spotlight indexing is explained"
        )

        var dnsContext = desktopBadBatteryContext
        dnsContext.dnsCPU = 25
        let dnsFix = Rules.build(dnsContext).first { $0.id == "dns" }
        assertTrue(dnsFix != nil, "DNS flush is suggested")
        assertTrue(dnsFix?.admin == true, "DNS flush requires admin")
        assertTrue(
            dnsFix?.command.contains("mDNSResponder") == true,
            "DNS flush targets the DNS responder"
        )

        var smbContext = desktopBadBatteryContext
        smbContext.smbCPU = 20
        smbContext.smbMounts = ["/Volumes/Media"]
        assertTrue(
            Rules.build(smbContext).contains { $0.id == "smb" },
            "Busy mounted SMB share is reported"
        )
        var idleSMBContext = smbContext
        idleSMBContext.smbCPU = 1
        assertFalse(
            Rules.build(idleSMBContext).contains { $0.id == "smb" },
            "Idle SMB share is not reported"
        )
        var unmountedSMBContext = smbContext
        unmountedSMBContext.smbMounts = []
        assertFalse(
            Rules.build(unmountedSMBContext).contains { $0.id == "smb" },
            "SMB CPU without a mount is not reported"
        )

        var mdmContext = desktopBadBatteryContext
        mdmContext.mdmEnrolled = true
        let mdmFixes = Rules.build(mdmContext)
        assertTrue(mdmFixes.contains { $0.id == "mdm" }, "Managed Mac is reported")
        assertTrue(
            mdmFixes.first { $0.id == "mdm" }?.command.isEmpty == true,
            "MDM rule never runs a command"
        )
        assertFalse(
            Rules.build(desktopBadBatteryContext).contains { $0.id == "mdm" },
            "Unmanaged Mac has no MDM rule"
        )

        // Sleep assertion rule (caffeinate)
        var caffeinateContext = genericContext
        caffeinateContext.sleepAssertions = [
            SleepAssertion(pid: 12345, process: "caffeinate", assertionType: "PreventUserIdleSystemSleep", name: "caffeinate")
        ]
        let caffeinateFixes = Rules.build(caffeinateContext)
        assertTrue(caffeinateFixes.contains { $0.id == "sleep-caffeinate-12345" }, "caffeinate fix suggested")
        if let fix = caffeinateFixes.first(where: { $0.id == "sleep-caffeinate-12345" }) {
            assertEqual(fix.command, "kill 12345", "Command terminates caffeinate")
            assertFalse(fix.admin, "No admin rights needed to stop user caffeinate")
            assertEqual(fix.severity, .medium, "Severity is medium")
        }

        // Peripheral battery rules
        var peripheralContext = genericContext
        peripheralContext.peripherals = [
            PeripheralBattery(name: "Magic Mouse", percent: 85),
            PeripheralBattery(name: "Magic Keyboard", percent: 15),
            PeripheralBattery(name: "Magic Trackpad", percent: 8)
        ]
        let peripheralFixes = Rules.build(peripheralContext)
        assertFalse(peripheralFixes.contains { $0.id == "peripheral-battery-magic-mouse" }, "Healthy peripheral produces no fix")
        assertTrue(peripheralFixes.contains { $0.id == "peripheral-battery-magic-keyboard" }, "15% keyboard produces warning")
        assertTrue(peripheralFixes.contains { $0.id == "peripheral-battery-magic-trackpad" }, "8% trackpad produces warning")
        if let keyboardFix = peripheralFixes.first(where: { $0.id == "peripheral-battery-magic-keyboard" }) {
            assertEqual(keyboardFix.severity, .medium, "15% battery has medium severity")
            assertTrue(keyboardFix.command.isEmpty, "Hardware warning has no command")
        }
        if let trackpadFix = peripheralFixes.first(where: { $0.id == "peripheral-battery-magic-trackpad" }) {
            assertEqual(trackpadFix.severity, .high, "8% battery has high severity")
        }

        // Every rule reads its copy from the catalogue, so no title can be blank.
        for fix in Rules.build(genericContext) + noBackupFixes + staleBackupFixes {
            assertFalse(fix.title.isEmpty, "Rule \(fix.id) has a title")
            assertFalse(fix.detail.isEmpty, "Rule \(fix.id) has a detail")
            assertFalse(fix.value.isEmpty, "Rule \(fix.id) has a value")
        }

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

        // MARK: - 4. History and alerts

        print("▸ Testing history, alerts and strings…")

        let day0 = Date(timeIntervalSince1970: 1_700_000_000)
        func historyEntry(
            _ offset: TimeInterval,
            score: Int,
            fixes: [HistoryFix] = []
        ) -> HistoryEntry {
            HistoryEntry(
                date: day0.addingTimeInterval(offset),
                score: score,
                fixes: fixes,
                memFreePct: 30,
                diskFreePct: 40,
                load1: 1
            )
        }

        // Appending keeps the newest entry first.
        var historyEntries: [HistoryEntry] = []
        for index in 0..<3 {
            historyEntries = ScanHistory.append(
                historyEntry(TimeInterval(index), score: 90 - index),
                to: historyEntries
            )
        }
        assertEqual(historyEntries.count, 3, "History stores every new scan")
        assertEqual(historyEntries.first?.score, 88, "Newest scan is first")
        assertEqual(historyEntries.last?.score, 90, "Oldest scan is last")

        // Pruning keeps exactly the limit and drops the oldest entries.
        historyEntries = []
        for index in 0..<35 {
            historyEntries = ScanHistory.append(
                historyEntry(TimeInterval(index), score: 100 - index),
                to: historyEntries
            )
        }
        assertEqual(historyEntries.count, ScanHistory.limit, "History is capped at 30 scans")
        assertEqual(historyEntries.first?.score, 66, "Newest scan survives pruning")
        assertEqual(historyEntries.last?.score, 95, "Only the oldest scans are pruned")

        // Previous-entry lookup respects the date.
        let older = historyEntry(0, score: 70)
        let newer = historyEntry(3600, score: 80)
        assertEqual(
            ScanHistory.previousEntry(before: newer.date, in: [newer, older])?.score,
            70,
            "Previous entry is the next older scan"
        )

        // "Since yesterday" only compares against an earlier calendar day.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let yesterday = historyEntry(0, score: 70)
        let today = historyEntry(86_400, score: 85)
        assertEqual(
            ScanHistory.previousDailyEntry(before: today.date, in: [today, yesterday], calendar: calendar)?.score,
            70,
            "Daily comparison finds yesterday's scan"
        )
        assertEqual(
            ScanHistory.previousDailyEntry(before: today.date, in: [today], calendar: calendar),
            nil,
            "Daily comparison has no result when only today exists"
        )

        // Change summary shows score movement and fix churn.
        let battery = HistoryFix(id: "battery", title: "Battery health")
        let diskFix = HistoryFix(id: "disk", title: "Disk space")
        let change = ScanHistory.change(
            from: historyEntry(0, score: 80, fixes: [battery]),
            to: historyEntry(3600, score: 70, fixes: [battery, diskFix])
        )
        assertEqual(change.scoreDelta, -10, "Score delta computed")
        assertEqual(change.addedFixes, [diskFix], "New recommendation detected")
        assertTrue(change.resolvedFixes.isEmpty, "No recommendation resolved")
        assertTrue(change.hasChanges, "Changed history flagged")
        assertTrue(
            ScanHistory.summary(for: change).contains("Score down 10 points"),
            "Summary mentions the score drop"
        )

        let resolved = ScanHistory.change(
            from: historyEntry(0, score: 70, fixes: [battery, diskFix]),
            to: historyEntry(3600, score: 80, fixes: [])
        )
        assertEqual(resolved.resolvedFixes, [battery, diskFix], "Resolved recommendations detected")
        assertTrue(resolved.hasChanges, "Resolved history flagged")

        let unchanged = ScanHistory.change(
            from: historyEntry(0, score: 80, fixes: [battery]),
            to: historyEntry(3600, score: 80, fixes: [battery])
        )
        assertFalse(unchanged.hasChanges, "Identical scans report no change")

        // Threshold alerts only fire when the score crosses downward.
        assertTrue(
            ScoreAlert.shouldNotify(previousScore: 75, currentScore: 60, threshold: 70, enabled: true),
            "Alert fires when score crosses below threshold"
        )
        assertFalse(
            ScoreAlert.shouldNotify(previousScore: 60, currentScore: 55, threshold: 70, enabled: true),
            "No repeat alert while already below threshold"
        )
        assertFalse(
            ScoreAlert.shouldNotify(previousScore: 75, currentScore: 60, threshold: 70, enabled: false),
            "No alert when notifications are off"
        )
        assertFalse(
            ScoreAlert.shouldNotify(previousScore: nil, currentScore: 40, threshold: 70, enabled: true),
            "No alert without a previous score"
        )
        assertFalse(
            ScoreAlert.shouldNotify(previousScore: 80, currentScore: 70, threshold: 70, enabled: true),
            "No alert when the score only reaches the threshold"
        )

        // String catalogue is complete and has a visible fallback.
        assertFalse(L10n.t("onboarding.title").isEmpty, "Onboarding title is defined")
        assertEqual(
            L10n.t("history.scoreUp", 5),
            "Score up 5 points",
            "Formatted string template applies values"
        )
        assertEqual(L10n.t("missing.key"), "missing.key", "Missing keys fall back to the key")
        assertTrue(L10n.keys.count > 20, "Catalogue contains the shipping strings")
        for (key, value) in L10n.strings {
            assertFalse(value.isEmpty, "String '\(key)' is not empty")
        }

        // Software update version comparison and parsing (Phase 5)
        print("▸ Testing UpdateCheck…")
        assertTrue(UpdateCheck.isVersion("1.2.1", newerThan: "1.2.0"), "Patch bump is recognized as newer")
        assertTrue(UpdateCheck.isVersion("v1.3.0", newerThan: "1.2.0"), "Minor bump with v prefix is recognized as newer")
        assertTrue(UpdateCheck.isVersion("2.0.0", newerThan: "1.9.9"), "Major bump is recognized as newer")
        assertFalse(UpdateCheck.isVersion("1.2.0", newerThan: "1.2.0"), "Same version is not newer")
        assertFalse(UpdateCheck.isVersion("1.1.9", newerThan: "1.2.0"), "Older version is not newer")
        assertFalse(UpdateCheck.isVersion("invalid", newerThan: "1.2.0"), "Malformed candidate is rejected")

        let sampleReleaseJSON = """
        {
          "tag_name": "v1.3.0",
          "html_url": "https://github.com/ShishirShekhar/macpulse/releases/tag/v1.3.0",
          "prerelease": false
        }
        """.data(using: .utf8)!
        let parsedRelease = UpdateCheck.parseRelease(data: sampleReleaseJSON)
        assertEqual(parsedRelease?.tagName ?? "", "v1.3.0", "Release tag_name is parsed")
        assertEqual(
            parsedRelease?.htmlURL ?? "",
            "https://github.com/ShishirShekhar/macpulse/releases/tag/v1.3.0",
            "Release html_url is parsed"
        )
        assertFalse(parsedRelease?.isPrerelease ?? true, "Release prerelease flag is parsed")

        let invalidReleaseJSON = "{}".data(using: .utf8)!
        assertEqual(UpdateCheck.parseRelease(data: invalidReleaseJSON), nil, "Invalid release JSON returns nil")

        // CheckResult attention items and status with peripherals & assertions
        let resultWithPeripherals = CheckResult(
            date: Date(),
            model: "Macmini9,1",
            modelName: "Mac mini (M1, 2020)",
            osVersion: "14.0",
            uptime: "2d",
            cpuCores: 8,
            load1: 0.5,
            load5: 0.5,
            load15: 0.5,
            memTotalGB: 16,
            memFreePct: 50,
            memCompressedGB: 1,
            swapUsedMB: 0,
            diskFreeGB: 200,
            diskTotalGB: 500,
            batteryHealthPct: 0,
            batteryCycles: 0,
            batteryCondition: "No battery",
            batteryCharge: 0,
            charging: false,
            onAC: true,
            kernelTaskCPU: 2,
            windowServerCPU: 5,
            notificationCPU: 1,
            spotlightIndexing: false,
            acSleepMinutes: 15,
            loginItems: [],
            launchAgentCount: 2,
            topProcesses: [],
            fixes: [],
            score: 100,
            sleepAssertions: [
                SleepAssertion(pid: 999, process: "caffeinate", assertionType: "PreventUserIdleSystemSleep", name: "caffeinate")
            ],
            peripherals: [
                PeripheralBattery(name: "Magic Mouse", percent: 8)
            ]
        )
        assertEqual(resultWithPeripherals.batteryStatus, .bad, "Peripheral with 8% battery causes bad batteryStatus even on desktop")
        assertEqual(resultWithPeripherals.sleepStatus, .warn, "caffeinate assertion causes warn sleepStatus")
        assertTrue(
            resultWithPeripherals.attentionItems.contains { $0.contains("caffeinate") },
            "Attention items report caffeinate blocking sleep"
        )
        assertTrue(
            resultWithPeripherals.attentionItems.contains { $0.contains("Magic Mouse") },
            "Attention items report low peripheral battery"
        )

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

