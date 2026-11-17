import Foundation

/// Checks power assertions to explain why a Mac is staying awake.
enum SleepProbe {
    static func sample() -> SleepAssertionSample {
        let output = Shell.value("pmset -g assertions")
        return ProbeParsers.sleepAssertions(output)
    }
}
