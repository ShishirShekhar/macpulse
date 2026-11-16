import Foundation

/// Reads free and total space on the data volume. MacPulse never measures the
/// read-only system volume, because that number never changes.
enum DiskProbe {
    static func sample() -> DiskSample {
        ProbeParsers.disk(Shell.value("df -k /System/Volumes/Data 2>/dev/null | tail -1"))
    }
}
