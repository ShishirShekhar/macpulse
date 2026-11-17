import Foundation

/// Reads whether this Mac is enrolled in mobile device management. This is used
/// for an informational rule only: MacPulse never disables MDM, profiles or
/// security settings.
enum ManagementProbe {
    static func sample() -> ManagementSample {
        let output = Shell.value("profiles status -type enrollment 2>/dev/null", timeout: 5)
        return ManagementSample(mdmEnrolled: ProbeParsers.mdmEnrolled(output))
    }
}
