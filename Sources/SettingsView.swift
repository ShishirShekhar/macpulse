import SwiftUI

struct ExcludableRuleDef: Identifiable {
    let id: String
    let name: String
    let detail: String
}

let availableExcludableRules: [ExcludableRuleDef] = [
    ExcludableRuleDef(id: "battery", name: "Battery health", detail: "Advice for failing or degraded laptop batteries"),
    ExcludableRuleDef(id: "disk", name: "Disk space", detail: "Warnings when free disk space drops below 10% or 15 GB"),
    ExcludableRuleDef(id: "purge", name: "Memory purge", detail: "Reclaim inactive RAM when free memory is under 10% or swap exceeds 1 GB"),
    ExcludableRuleDef(id: "notifications", name: "Notification Center", detail: "Restart suggestions when NotificationCenter consumes CPU"),
    ExcludableRuleDef(id: "sleep", name: "Sleep timer", detail: "Offer to increase sleep timer on AC power from 1–5 minutes"),
    ExcludableRuleDef(id: "thermal", name: "Thermal throttling", detail: "Advice when kernel_task throttles the CPU due to heat"),
    ExcludableRuleDef(id: "windowserver", name: "WindowServer animation", detail: "Advice to close animated background tabs causing high CPU"),
    ExcludableRuleDef(id: "quit", name: "Heavy apps", detail: "Suggestions to gracefully quit GUI apps using over 60% CPU"),
    ExcludableRuleDef(id: "brew", name: "Homebrew services", detail: "Suggestions to stop idle running background Homebrew services"),
    ExcludableRuleDef(id: "helper", name: "Background helpers", detail: "Suggestions to disable third-party startup helpers and daemons")
]

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text("MacPulse Settings")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Spacer()
                }

                // Section 1: Scan Schedule
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Daily Background Check", systemImage: "clock.badge.checkmark")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { model.dailyCheck },
                            set: { model.setDailyCheck($0) }
                        ))
                        .toggleStyle(.switch)
                    }

                    Text("MacPulse uses a native per-user LaunchAgent (com.macpulse.daily) to run a silent check once a day without keeping an app open in the dock.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if model.dailyCheck {
                        Divider()

                        HStack(spacing: 12) {
                            Text("Scheduled Time:")
                                .font(.system(size: 13, weight: .medium))

                            // Hour picker
                            Picker("Hour", selection: Binding(
                                get: { model.scheduleHour },
                                set: { model.updateSchedule(hour: $0, minute: model.scheduleMinute) }
                            )) {
                                ForEach(0..<24, id: \.self) { h in
                                    let displayH = h % 12 == 0 ? 12 : h % 12
                                    let ampm = h < 12 ? "AM" : "PM"
                                    Text(String(format: "%d %@", displayH, ampm)).tag(h)
                                }
                            }
                            .frame(width: 110)

                            // Minute picker
                            Picker("Minute", selection: Binding(
                                get: { model.scheduleMinute },
                                set: { model.updateSchedule(hour: model.scheduleHour, minute: $0) }
                            )) {
                                ForEach([0, 15, 30, 45], id: \.self) { m in
                                    Text(String(format: ":%02d", m)).tag(m)
                                }
                            }
                            .frame(width: 80)

                            Spacer()

                            Text("Runs daily at \(model.formattedScheduleTime)")
                                .font(.caption)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                .card()

                // Section 2: Rule Exclusions
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Rule Exclusions", systemImage: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        if !model.excludedRules.isEmpty {
                            Text("\(model.excludedRules.count) excluded")
                                .font(.caption2)
                                .foregroundStyle(Theme.warn)
                        }
                    }

                    Text("Turn off recommendations you do not wish to see. Excluded rules will not produce suggestions in interactive or background scans.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    VStack(spacing: 10) {
                        ForEach(availableExcludableRules) { rule in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rule.name)
                                        .font(.system(size: 13, weight: .medium))
                                    Text(rule.detail)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { !model.excludedRules.contains(rule.id) },
                                    set: { _ in model.toggleRuleExclusion(rule.id) }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }
                            if rule.id != availableExcludableRules.last?.id {
                                Divider().opacity(0.4)
                            }
                        }
                    }
                }
                .card()

                // Section 3: Declined Fixes
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Declined Suggestions", systemImage: "xmark.bin")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        if !model.declined.isEmpty {
                            Button("Restore All") {
                                model.restoreAll()
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(Theme.accent)
                            .font(.caption)
                        }
                    }

                    if model.declined.isEmpty {
                        Text("No suggestions have been declined.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(Array(model.declined).sorted(), id: \.self) { id in
                                HStack {
                                    Text(id)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Restore") {
                                        model.declined.remove(id)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
                .card()

                // Section 4: History
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(L10n.t("history.title"), systemImage: "chart.xyaxis.line")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text(L10n.t("history.count", model.history.count))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text("MacPulse keeps the last \(ScanHistory.limit) scans locally so it can show a score trend and what changed since yesterday.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button(L10n.t("onboarding.again")) {
                            model.showSettings = false
                            model.showOnboardingAgain()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()

                        Button(L10n.t("history.clear")) {
                            model.clearHistory()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.history.isEmpty)
                    }
                }
                .card()

                // Section 5: Menu bar and alerts
                VStack(alignment: .leading, spacing: 12) {
                    Label("Menu Bar & Alerts", systemImage: "bell.badge")
                        .font(.system(size: 14, weight: .semibold))

                    Toggle(isOn: Binding(
                        get: { model.menuBarEnabled },
                        set: { model.setMenuBarEnabled($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("menubar.toggle"))
                                .font(.system(size: 13, weight: .medium))
                            Text(L10n.t("menubar.toggle.detail"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()

                    Toggle(isOn: Binding(
                        get: { model.scoreNotificationsEnabled },
                        set: { model.setScoreNotifications($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("notifications.toggle"))
                                .font(.system(size: 13, weight: .medium))
                            Text(L10n.t("notifications.toggle.detail"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    if model.scoreNotificationsEnabled {
                        HStack(spacing: 12) {
                            Text(L10n.t("notifications.threshold"))
                                .font(.system(size: 13, weight: .medium))
                            Picker("", selection: Binding(
                                get: { model.scoreNotificationThreshold },
                                set: { model.setNotificationThreshold($0) }
                            )) {
                                ForEach(Array(stride(from: 30, through: 95, by: 5)), id: \.self) { value in
                                    Text("\(value)").tag(value)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 80)
                            Spacer()
                        }
                    }
                }
                .card()

                // Section 6: Advanced & Reset
                VStack(alignment: .leading, spacing: 12) {
                    Label("Advanced & Privacy", systemImage: "lock.shield")
                        .font(.system(size: 14, weight: .semibold))

                    Toggle(isOn: Binding(
                        get: { model.showAdvancedCommands },
                        set: { model.showAdvancedCommands = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Always show command preview")
                                .font(.system(size: 13, weight: .medium))
                            Text("Expands the exact shell command on all fix cards without needing to click Preview.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset All Data")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.bad)
                            Text("Clears cached check results, recent activity history, and restores default preferences.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reset Everything") {
                            model.resetAllData()
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.bad)
                        .controlSize(.small)
                    }
                }
                .card()
            }
            .padding(20)
        }
        .frame(minWidth: 540, idealWidth: 600, minHeight: 460, idealHeight: 560)
    }
}
