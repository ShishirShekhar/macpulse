import Foundation

/// Installs a per-user LaunchAgent that runs `MacPulse --check` once a day.
enum LaunchAgent {
    static let label = "com.macpulse.daily"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MacPulse.log")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// Writes the plist and loads it. Returns an error message on failure.
    @discardableResult
    static func install(hour: Int = 9, minute: Int = 0) -> String? {
        guard let executable = Bundle.main.executablePath else {
            return "Could not locate the MacPulse executable"
        }

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable, "--check"],
            "RunAtLoad": false,
            "ProcessType": "Background",
            "StartCalendarInterval": ["Hour": hour, "Minute": minute],
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path
        ]

        do {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: logURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try data.write(to: plistURL, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: plistURL.path
            )
        } catch {
            return "Could not write the launch agent: \(error.localizedDescription)"
        }

        let result = Shell.run(
            "launchctl bootout gui/$(id -u)/\(label) >/dev/null 2>&1; " +
            "launchctl bootstrap gui/$(id -u) \"\(plistURL.path)\""
        )
        if result.code != 0 {
            return "launchctl could not load the daily check"
        }
        return nil
    }

    static func uninstall() {
        Shell.run("launchctl bootout gui/$(id -u)/\(label) >/dev/null 2>&1; true")
        try? FileManager.default.removeItem(at: plistURL)
    }
}
