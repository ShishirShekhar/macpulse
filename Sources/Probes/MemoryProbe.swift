import Foundation

/// Reads physical memory, free percentage, compressed memory and swap.
enum MemoryProbe {
    static func sample() -> MemorySample {
        let totalGB = (Double(Shell.value("sysctl -n hw.memsize")) ?? 0) / 1_073_741_824
        let pressure = Shell.value("memory_pressure 2>/dev/null | tail -3")
        let vmStat = Shell.value("vm_stat")
        let swap = Shell.value("sysctl -n vm.swapusage")

        return MemorySample(
            totalGB: totalGB,
            freePercent: ProbeParsers.freeMemoryPercent(pressure),
            compressedGB: ProbeParsers.compressedGB(vmStat: vmStat, pageSizeFallback: 16384),
            swapUsedMB: ProbeParsers.swapUsedMB(swap)
        )
    }
}
