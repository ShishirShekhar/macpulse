import SwiftUI

struct ExcludableRuleDef: Identifiable {
    let id: String
    var name: String { L10n.t("settings.rule.\(id).name") }
    var detail: String { L10n.t("settings.rule.\(id).detail") }
}

let availableExcludableRules: [ExcludableRuleDef] = [
    ExcludableRuleDef(id: "battery"),
    ExcludableRuleDef(id: "disk"),
    ExcludableRuleDef(id: "purge"),
    ExcludableRuleDef(id: "notifications"),
    ExcludableRuleDef(id: "sleep"),
    ExcludableRuleDef(id: "thermal"),
    ExcludableRuleDef(id: "windowserver"),
    ExcludableRuleDef(id: "quit"),
    ExcludableRuleDef(id: "brew"),
    ExcludableRuleDef(id: "helper"),
    ExcludableRuleDef(id: "timemachine"),
    ExcludableRuleDef(id: "backup"),
    ExcludableRuleDef(id: "spotlight"),
    ExcludableRuleDef(id: "dns"),
    ExcludableRuleDef(id: "smb"),
    ExcludableRuleDef(id: "mdm"),
    ExcludableRuleDef(id: "sleep-caffeinate"),
    ExcludableRuleDef(id: "peripheral-battery")
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
                    Text(L10n.t("settings.title"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Spacer()
                }

                // Section 1: Scan Schedule
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(L10n.t("settings.schedule.title"), systemImage: "clock.badge.checkmark")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { model.dailyCheck },
                            set: { model.setDailyCheck($0) }
                        ))
                        .toggleStyle(.switch)
                    }

                    Text(L10n.t("settings.schedule.detail"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if model.dailyCheck {
                        Divider()

                        HStack(spacing: 12) {
                            Text(L10n.t("settings.schedule.time"))
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

                            Text(L10n.t("settings.schedule.runsDailyAt", model.formattedScheduleTime))
                                .font(.caption)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                .card()

                // Section 2: Rule Exclusions
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(L10n.t("settings.exclusions.title"), systemImage: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        if !model.excludedRules.isEmpty {
                            Text(L10n.t("settings.exclusions.count", model.excludedRules.count))
                                .font(.caption2)
                                .foregroundStyle(Theme.warn)
                        }
                    }

                    Text(L10n.t("settings.exclusions.detail"))
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
                        Label(L10n.t("settings.declined.title"), systemImage: "xmark.bin")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        if !model.declined.isEmpty {
                            Button(L10n.t("settings.declined.restoreAll")) {
                                model.restoreAll()
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(Theme.accent)
                            .font(.caption)
                        }
                    }

                    if model.declined.isEmpty {
                        Text(L10n.t("settings.declined.empty"))
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
                                    Button(L10n.t("settings.declined.restore")) {
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

                    Text(L10n.t("settings.history.detail", ScanHistory.limit))
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
                    Label(L10n.t("settings.menubarAndAlerts.title"), systemImage: "bell.badge")
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

                // Section 6: Language
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(L10n.t("settings.language.title"), systemImage: "globe")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }

                    Text(L10n.t("settings.language.detail"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    HStack(spacing: 12) {
                        Text(L10n.t("settings.language.label"))
                            .font(.system(size: 13, weight: .medium))

                        Picker("", selection: Binding(
                            get: { model.selectedLanguage },
                            set: { model.selectedLanguage = $0 }
                        )) {
                            Text(L10n.t("settings.language.system")).tag("system")
                            Text("English").tag("en")
                            Text("Deutsch").tag("de")
                            Text("Français").tag("fr")
                            Text("Español").tag("es")
                            Text("日本語").tag("ja")
                        }
                        .labelsHidden()
                        .frame(width: 170)

                        Spacer()
                    }
                }
                .card()

                // Section 7: Software Updates (Opt-in)
                VStack(alignment: .leading, spacing: 12) {
                    Label(L10n.t("updates.title"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))

                    Toggle(isOn: Binding(
                        get: { model.checkForUpdates },
                        set: { model.checkForUpdates = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("updates.toggle"))
                                .font(.system(size: 13, weight: .medium))
                            Text(L10n.t("updates.toggle.detail"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()

                    HStack {
                        Button(L10n.t("updates.checkNow")) {
                            model.triggerUpdateCheck(manual: true)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.isCheckingForUpdates)

                        if model.isCheckingForUpdates {
                            ProgressView().controlSize(.small)
                                .padding(.leading, 6)
                        }

                        if let status = model.updateStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(model.availableUpdate != nil ? Theme.accent : .secondary)
                                .padding(.leading, 6)
                        }

                        Spacer()

                        if let release = model.availableUpdate, let url = URL(string: release.htmlURL) {
                            Button(L10n.t("updates.download")) {
                                NSWorkspace.shared.open(url)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(Theme.accent)
                        }
                    }
                }
                .card()

                // Section 8: Advanced & Reset
                VStack(alignment: .leading, spacing: 12) {
                    Label(L10n.t("settings.advanced.title"), systemImage: "lock.shield")
                        .font(.system(size: 14, weight: .semibold))

                    Toggle(isOn: Binding(
                        get: { model.showAdvancedCommands },
                        set: { model.showAdvancedCommands = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("settings.advanced.preview.title"))
                                .font(.system(size: 13, weight: .medium))
                            Text(L10n.t("settings.advanced.preview.detail"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("report.copy"))
                                .font(.system(size: 13, weight: .medium))
                            Text("Copies a clean, privacy-preserving markdown health report to your clipboard.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(L10n.t("report.copy")) {
                            model.copyDiagnosticReport()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.result == nil)
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("settings.advanced.reset.title"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.bad)
                            Text(L10n.t("settings.advanced.reset.detail"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(L10n.t("settings.advanced.reset.button")) {
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
