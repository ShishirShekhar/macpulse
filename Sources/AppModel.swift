import Foundation
import SwiftUI
import AppKit

// MARK: - Supporting types

enum BannerKind {
    case success, failure, info

    var color: Color {
        switch self {
        case .success: return Theme.good
        case .failure: return Theme.bad
        case .info: return Theme.accentAlt
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct Banner: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let kind: BannerKind

    static func == (lhs: Banner, rhs: Banner) -> Bool { lhs.id == rhs.id }
}

enum ActivityState {
    case running, success, failure, undone
}

struct ActivityItem: Identifiable {
    let id: UUID
    let title: String
    let detail: String
    let state: ActivityState
    let date: Date
    let undoCommand: String?
    let admin: Bool

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        state: ActivityState,
        date: Date = Date(),
        undoCommand: String? = nil,
        admin: Bool = false
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
        self.date = date
        self.undoCommand = undoCommand
        self.admin = admin
    }
}

// MARK: - Model

final class AppModel: ObservableObject {
    @Published var result: CheckResult?
    @Published var isChecking = false
    @Published var runningFixID: String?
    @Published var activity: [ActivityItem] = []
    @Published var banner: Banner?
    @Published var dailyCheck = false
    @Published var showDeclined = false
    @Published var showActivity = true
    @Published var lastError: String?
    @Published var declined: Set<String> = [] {
        didSet { UserDefaults.standard.set(Array(declined), forKey: declinedKey) }
    }
    @Published var excludedRules: Set<String> = [] {
        didSet { UserDefaults.standard.set(Array(excludedRules), forKey: excludedRulesKey) }
    }
    @Published var showAdvancedCommands = false {
        didSet { UserDefaults.standard.set(showAdvancedCommands, forKey: advancedCommandsKey) }
    }
    @Published var scheduleHour: Int = 9
    @Published var scheduleMinute: Int = 0
    @Published var showScoreBreakdown = false
    @Published var showSettings = false

    private let declinedKey = "declinedFixIDs"
    private let excludedRulesKey = "excludedRuleIDs"
    private let advancedCommandsKey = "showAdvancedCommands"
    private let scheduleHourKey = "scheduleHour"
    private let scheduleMinuteKey = "scheduleMinute"
    private var bannerToken = UUID()

    init() {
        declined = Set(UserDefaults.standard.stringArray(forKey: declinedKey) ?? [])
        excludedRules = Set(UserDefaults.standard.stringArray(forKey: excludedRulesKey) ?? [])
        showAdvancedCommands = UserDefaults.standard.bool(forKey: advancedCommandsKey)

        if let savedSchedule = LaunchAgent.installedSchedule {
            scheduleHour = savedSchedule.hour
            scheduleMinute = savedSchedule.minute
        } else {
            let savedH = UserDefaults.standard.integer(forKey: scheduleHourKey)
            scheduleHour = savedH > 0 ? savedH : 9
            scheduleMinute = UserDefaults.standard.integer(forKey: scheduleMinuteKey)
        }

        result = SystemCheck.load()

        // First launch: schedule the daily background check automatically.
        if !LaunchAgent.isInstalled {
            _ = LaunchAgent.install(hour: scheduleHour, minute: scheduleMinute)
        }
        dailyCheck = LaunchAgent.isInstalled
    }

    // MARK: Derived state

    var visibleFixes: [FixSuggestion] {
        guard let result else { return [] }
        return result.fixes.filter { fix in
            if declined.contains(fix.id) { return false }
            for excluded in excludedRules {
                if fix.id == excluded || fix.id.hasPrefix("\(excluded)-") {
                    return false
                }
            }
            return true
        }
    }

    var declinedFixes: [FixSuggestion] {
        guard let result else { return [] }
        return result.fixes.filter { declined.contains($0.id) }
    }

    // MARK: Checks

    func startIfNeeded() {
        guard !isChecking else { return }
        if let cached = result {
            if Date().timeIntervalSince(cached.date) > 6 * 3600 {
                runCheck()
            }
        } else {
            runCheck()
        }
    }

    func runCheck() {
        guard !isChecking else { return }
        isChecking = true

        DispatchQueue.global(qos: .userInitiated).async {
            let fresh = SystemCheck.collect(interactive: true)
            SystemCheck.save(fresh)

            DispatchQueue.main.async {
                self.result = fresh
                self.isChecking = false
                self.banner = Banner(
                    text: "Checked — score \(fresh.score), \(fresh.fixes.count) suggestion\(fresh.fixes.count == 1 ? "" : "s")",
                    kind: .info
                )
                self.scheduleBannerClear()
            }
        }
    }

    // MARK: Fixes

    func approve(_ fix: FixSuggestion) {
        guard runningFixID == nil else { return }

        runningFixID = fix.id
        let isNativeQuit = fix.nativeAction == "quit"
        let item = ActivityItem(
            title: fix.title,
            detail: isNativeQuit
                ? "Asking the app to quit…"
                : (fix.admin ? "Waiting for administrator approval…" : "Running…"),
            state: .running,
            undoCommand: fix.undoCommand,
            admin: fix.admin
        )
        activity.insert(item, at: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            let outcome: (output: String, code: Int32)
            if isNativeQuit, let target = fix.nativeTarget.flatMap(Int32.init) {
                outcome = self.quitApp(pid: target, name: fix.title)
            } else {
                outcome = fix.admin ? Shell.admin(fix.command) : Shell.run(fix.command)
            }
            let output = outcome.output.trimmingCharacters(in: .whitespacesAndNewlines)
            let success = outcome.code == 0

            DispatchQueue.main.async {
                self.runningFixID = nil

                let detail: String
                if success {
                    detail = output.isEmpty ? "Completed successfully" : output
                } else {
                    detail = output.isEmpty ? "Failed with exit code \(outcome.code)" : output
                }
                self.updateActivity(
                    id: item.id,
                    detail: detail,
                    state: success ? .success : .failure
                )
                self.activity = Array(self.activity.prefix(12))

                self.banner = Banner(
                    text: success ? "\(fix.title) — done" : "\(fix.title) — failed",
                    kind: success ? .success : .failure
                )
                self.scheduleBannerClear()

                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        self.runCheck()
                    }
                }
            }
        }
    }

    /// Re-runs the reverse command of a completed fix. The original activity item
    /// is marked as undone so it cannot be reverted twice.
    func undo(_ item: ActivityItem) {
        guard runningFixID == nil, let command = item.undoCommand else { return }

        runningFixID = "undo-\(item.id.uuidString)"
        let undoItem = ActivityItem(
            title: "Undo: \(item.title)",
            detail: item.admin ? "Waiting for administrator approval…" : "Running…",
            state: .running
        )
        activity.insert(undoItem, at: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            let outcome = item.admin ? Shell.admin(command) : Shell.run(command)
            let output = outcome.output.trimmingCharacters(in: .whitespacesAndNewlines)
            let success = outcome.code == 0

            DispatchQueue.main.async {
                self.runningFixID = nil
                self.updateActivity(
                    id: undoItem.id,
                    detail: output.isEmpty
                        ? (success ? "Reverted successfully" : "Failed with exit code \(outcome.code)")
                        : output,
                    state: success ? .success : .failure
                )
                if success {
                    self.updateActivity(
                        id: item.id,
                        detail: "Reverted — the previous setting was restored.",
                        state: .undone
                    )
                    self.banner = Banner(text: "Undone: \(item.title)", kind: .info)
                } else {
                    self.banner = Banner(text: "Could not undo \(item.title)", kind: .failure)
                }
                self.activity = Array(self.activity.prefix(12))
                self.scheduleBannerClear()

                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        self.runCheck()
                    }
                }
            }
        }
    }

    func clearActivity() {
        activity.removeAll()
    }

    private func updateActivity(id: UUID, detail: String, state: ActivityState) {
        guard let index = activity.firstIndex(where: { $0.id == id }) else { return }
        let old = activity[index]
        activity[index] = ActivityItem(
            id: old.id,
            title: old.title,
            detail: detail,
            state: state,
            date: old.date,
            undoCommand: old.undoCommand,
            admin: old.admin
        )
    }

    /// Sends the normal macOS Quit request (never a force kill) and waits briefly
    /// so the user gets a truthful result instead of an instant "done".
    private func quitApp(pid: Int32, name: String) -> (output: String, code: Int32) {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return ("That app is no longer running.", 0)
        }
        let appName = app.localizedName
            ?? name.replacingOccurrences(of: "Quit ", with: "")
        guard app.terminate() else {
            return ("macOS refused to ask \(appName) to quit.", 1)
        }
        let deadline = Date().addingTimeInterval(5)
        while !app.isTerminated && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        if app.isTerminated {
            return ("\(appName) quit normally.", 0)
        }
        return ("\(appName) is waiting for you — save any open work, then quit it from the Dock.", 1)
    }

    func decline(_ fix: FixSuggestion) {
        declined.insert(fix.id)
        banner = Banner(text: "Declined: \(fix.title)", kind: .info)
        scheduleBannerClear()
    }

    func restore(_ fix: FixSuggestion) {
        declined.remove(fix.id)
    }

    func restoreAll() {
        declined.removeAll()
    }

    // MARK: Daily schedule

    var formattedScheduleTime: String {
        let h = scheduleHour % 12 == 0 ? 12 : scheduleHour % 12
        let ampm = scheduleHour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, scheduleMinute, ampm)
    }

    func updateSchedule(hour: Int, minute: Int) {
        scheduleHour = hour
        scheduleMinute = minute
        UserDefaults.standard.set(hour, forKey: scheduleHourKey)
        UserDefaults.standard.set(minute, forKey: scheduleMinuteKey)
        if dailyCheck {
            if let error = LaunchAgent.install(hour: hour, minute: minute) {
                banner = Banner(text: error, kind: .failure)
            } else {
                banner = Banner(text: "Daily check rescheduled for \(formattedScheduleTime)", kind: .success)
            }
            scheduleBannerClear()
        }
    }

    func setDailyCheck(_ enabled: Bool) {
        if enabled {
            if let error = LaunchAgent.install(hour: scheduleHour, minute: scheduleMinute) {
                banner = Banner(text: error, kind: .failure)
            } else {
                banner = Banner(text: "Daily check scheduled for \(formattedScheduleTime)", kind: .success)
            }
        } else {
            LaunchAgent.uninstall()
            banner = Banner(text: "Daily check turned off", kind: .info)
        }
        dailyCheck = LaunchAgent.isInstalled
        scheduleBannerClear()
    }

    // MARK: Rules and Preferences

    func toggleRuleExclusion(_ ruleID: String) {
        if excludedRules.contains(ruleID) {
            excludedRules.remove(ruleID)
        } else {
            excludedRules.insert(ruleID)
        }
    }

    func resetAllData() {
        SystemCheck.clearCache()
        result = nil
        activity.removeAll()
        declined.removeAll()
        excludedRules.removeAll()
        showAdvancedCommands = false
        UserDefaults.standard.removeObject(forKey: declinedKey)
        UserDefaults.standard.removeObject(forKey: excludedRulesKey)
        UserDefaults.standard.removeObject(forKey: advancedCommandsKey)
        banner = Banner(text: "All MacPulse data and preferences reset", kind: .info)
        scheduleBannerClear()
    }

    // MARK: Banner

    private func scheduleBannerClear() {
        let token = UUID()
        bannerToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.bannerToken == token else { return }
            self.banner = nil
        }
    }
}
