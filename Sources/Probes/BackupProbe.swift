import Foundation

/// Reads Time Machine's destination and latest backup. Both commands are short
/// and read-only; a Mac with no backup disk simply reports no destination.
enum BackupProbe {
    static func sample() -> BackupSample {
        let destinationInfo = Shell.value("tmutil destinationinfo 2>/dev/null", timeout: 5)
        let hasDestination = ProbeParsers.hasTimeMachineDestination(destinationInfo)
        guard hasDestination else {
            return BackupSample(hasDestination: false, lastBackup: nil)
        }

        let latest = Shell.value("tmutil latestbackup 2>/dev/null", timeout: 5)
        return BackupSample(
            hasDestination: true,
            lastBackup: ProbeParsers.latestBackupDate(latest)
        )
    }
}
