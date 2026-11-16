import Foundation
import Darwin

/// Runs short-lived system commands with a hard timeout and a stable C locale,
/// so parsing never depends on the user's language or a stuck dialog.
enum Shell {
    static let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    static let timedOutCode: Int32 = 124

    private static var baseEnvironment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = defaultPath
        environment["LC_ALL"] = "C"
        environment["LANG"] = "C"
        environment["LANGUAGE"] = "C"
        return environment
    }

    @discardableResult
    static func run(_ command: String, timeout: TimeInterval = 8) -> (output: String, code: Int32) {
        let script = "export PATH=\(defaultPath):$PATH; \(command)"
        return exec("/bin/zsh", ["-c", script], timeout: timeout)
    }

    @discardableResult
    static func exec(
        _ path: String,
        _ arguments: [String],
        timeout: TimeInterval = 8
    ) -> (output: String, code: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.environment = baseEnvironment
        process.standardInput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return ("Failed to launch \(path): \(error.localizedDescription)", -1)
        }

        var captured = Data()
        let captureLock = NSLock()
        let reader = DispatchGroup()
        reader.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            captureLock.lock()
            captured = data
            captureLock.unlock()
            reader.leave()
        }

        let deadline = Date().addingTimeInterval(max(0.1, timeout))
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }

        var timedOut = false
        if process.isRunning {
            timedOut = true
            process.terminate()
            let graceDeadline = Date().addingTimeInterval(0.4)
            while process.isRunning && Date() < graceDeadline {
                Thread.sleep(forTimeInterval: 0.02)
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            process.waitUntilExit()
        }

        _ = reader.wait(timeout: .now() + 1)
        captureLock.lock()
        let data = captured
        captureLock.unlock()

        var output = String(data: data, encoding: .utf8) ?? ""
        if timedOut {
            if !output.isEmpty && !output.hasSuffix("\n") { output += "\n" }
            output += "(Command timed out after \(Int(timeout))s)"
            return (output, timedOutCode)
        }
        return (output, process.terminationStatus)
    }

    /// Runs a command as root through the standard macOS authorization dialog.
    /// The timeout is deliberately long because it includes user interaction.
    @discardableResult
    static func admin(_ command: String, timeout: TimeInterval = 300) -> (output: String, code: Int32) {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        return exec("/usr/bin/osascript", ["-e", script], timeout: timeout)
    }

    static func value(_ command: String, timeout: TimeInterval = 8) -> String {
        run(command, timeout: timeout).output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
