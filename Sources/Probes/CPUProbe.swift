import Foundation

/// Reads the machine identity and the current load average.
enum CPUProbe {
    static func sample() -> CPUSample {
        let cores = Int(Shell.value("sysctl -n hw.ncpu")) ?? 8
        let performanceCores = Int(Shell.value("sysctl -n hw.perflevel0.physicalcpu")) ?? 0
        let efficiencyCores = Int(Shell.value("sysctl -n hw.perflevel1.physicalcpu")) ?? 0

        return CPUSample(
            modelIdentifier: Shell.value("sysctl -n hw.model"),
            chip: Shell.value("sysctl -n machdep.cpu.brand_string"),
            cores: cores,
            performanceCores: performanceCores > 0 ? performanceCores : cores,
            efficiencyCores: efficiencyCores,
            isAppleSilicon: Shell.value("sysctl -n hw.optional.arm64") == "1",
            load: ProbeParsers.loadAverage(Shell.value("sysctl -n vm.loadavg"))
        )
    }
}
