import Foundation

/// Reads OS version, boot time, uptime and the AC sleep timer.
enum SystemProbe {
    static func sample(now: Date = Date()) -> SystemSample {
        let version = Shell.value("sw_vers -productVersion")
        let boot = ProbeParsers.bootSeconds(Shell.value("sysctl -n kern.boottime"))

        return SystemSample(
            osVersion: version,
            osMajor: Int(version.split(separator: ".").first ?? "") ?? 0,
            uptime: ProbeParsers.uptime(bootSeconds: boot, now: now),
            acSleepMinutes: ProbeParsers.acSleepMinutes(Shell.value("pmset -g custom"))
        )
    }
}
