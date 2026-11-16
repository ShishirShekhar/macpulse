import Foundation

/// Reads battery health from IORegistry. Desktops report no battery, and every
/// battery rule is gated on that so a Mac mini is never told to service one.
enum BatteryProbe {
    static func sample() -> BatterySample {
        ProbeParsers.battery(Shell.value("ioreg -rn AppleSmartBattery"))
    }
}
