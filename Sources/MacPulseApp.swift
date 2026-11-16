import SwiftUI
import AppKit

struct MacPulseUI: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("MacPulse") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 920, minHeight: 640)
        }
        .defaultSize(width: 1040, height: 780)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Check Now") {
                    model.runCheck()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

@main
struct Launcher {
    static func main() {
        if CommandLine.arguments.contains("--check") {
            let result = SystemCheck.collect(interactive: false)
            SystemCheck.save(result)
            let line = "MacPulse daily check — score \(result.score), \(result.fixes.count) suggestions\n"
            FileHandle.standardOutput.write(Data(line.utf8))
            exit(0)
        }

        MacPulseUI.main()
    }
}
