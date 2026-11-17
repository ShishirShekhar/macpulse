import SwiftUI
import AppKit

/// Contents of the optional menu bar extra. It only reads state; every action
/// goes through the same `AppModel` methods as the main window.
struct MenuBarContent: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let result = model.result {
            Text(L10n.t("menubar.score", result.score, result.scoreLabel))
            Divider()
        } else {
            Text(L10n.t("menubar.noScan"))
            Divider()
        }

        Button(L10n.t("common.checkNow")) {
            model.runCheck()
        }
        .disabled(model.isChecking)

        Button(L10n.t("menubar.open")) {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }

        Divider()

        Button("Quit MacPulse") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

/// Compact label used by `MenuBarExtra`.
struct MenuBarLabel: View {
    let score: Int?

    var body: some View {
        Label(
            score.map(String.init) ?? "—",
            systemImage: "waveform.path.ecg"
        )
        .accessibilityLabel(
            score.map { L10n.t("menubar.score", $0, "") } ?? L10n.t("menubar.noScan")
        )
    }
}
