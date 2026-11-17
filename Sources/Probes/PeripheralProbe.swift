import Foundation

/// Reads battery charge of connected Bluetooth and Apple HID peripherals.
enum PeripheralProbe {
    static func sample() -> [PeripheralBattery] {
        let output = Shell.value("ioreg -r -l -k BatteryPercent")
        return ProbeParsers.peripheralBatteries(output)
    }
}
