import SwiftUI
import AppKit

// MARK: - Theme

enum Theme {
    static let accent = Color(red: 0.16, green: 0.74, blue: 0.68)
    static let accentAlt = Color(red: 0.30, green: 0.55, blue: 0.96)
    static let good = Color(red: 0.20, green: 0.72, blue: 0.42)
    static let warn = Color(red: 0.95, green: 0.63, blue: 0.16)
    static let bad = Color(red: 0.92, green: 0.30, blue: 0.30)
}

extension Status {
    var color: Color {
        switch self {
        case .good: return Theme.good
        case .warn: return Theme.warn
        case .bad: return Theme.bad
        }
    }
}

extension Severity {
    var color: Color {
        switch self {
        case .high: return Theme.bad
        case .medium: return Theme.warn
        case .low: return Theme.accentAlt
        }
    }
}

// MARK: - Card styling

private struct PanelStyle: ViewModifier {
    var padded: Bool

    func body(content: Content) -> some View {
        content
            .padding(padded ? 16 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            )
    }
}

extension View {
    func card(padded: Bool = true) -> some View {
        modifier(PanelStyle(padded: padded))
    }
}

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            background

            if let result = model.result {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HeaderView(result: result)

                        if model.history.count > 1, let change = model.changeSinceYesterday {
                            HistorySection(
                                history: model.history,
                                change: change,
                                isEarlierDay: model.comparisonIsFromEarlierDay
                            )
                        }

                        if model.showScoreBreakdown, let subscores = result.subscores, !subscores.isEmpty {
                            ScoreBreakdownView(subscores: subscores)
                        }

                        if !result.attentionItems.isEmpty {
                            AttentionView(items: result.attentionItems)
                        }

                        SectionLabel(title: L10n.t("dashboard.systemHealth"), icon: "gauge.medium")
                        MetricGrid(result: result)

                        HStack(spacing: 6) {
                            SectionLabel(title: L10n.t("dashboard.recommendedFixes"), icon: "wrench.and.screwdriver.fill")
                            CountBadge(count: model.visibleFixes.count)
                            Spacer()
                        }
                        FixesView()

                        if !model.activity.isEmpty {
                            ActivitySection()
                        }

                        SectionLabel(title: L10n.t("dashboard.topProcesses"), icon: "list.bullet.rectangle")
                        ProcessSection(processes: result.topProcesses)

                        Footer(result: result)
                    }
                    .padding(20)
                    .frame(maxWidth: 1060)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.automatic)
            } else if model.isChecking {
                LoadingView()
            } else {
                ErrorOrEmptyView()
            }

            if let banner = model.banner {
                BannerView(banner: banner)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .sheet(isPresented: Binding(
            get: { model.showSettings },
            set: { model.showSettings = $0 }
        )) {
            VStack(alignment: .trailing, spacing: 0) {
                HStack {
                    Spacer()
                    Button("Done") {
                        model.showSettings = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding([.top, .trailing], 16)
                }
                SettingsView()
                    .environmentObject(model)
            }
        }
        .sheet(isPresented: Binding(
            get: { model.showOnboarding },
            set: { model.showOnboarding = $0 }
        )) {
            OnboardingView()
                .environmentObject(model)
                .interactiveDismissDisabled()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: model.banner?.id)
        .onAppear { model.startIfNeeded() }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Theme.accent.opacity(0.07),
                Theme.accentAlt.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Header

struct HeaderView: View {
    @EnvironmentObject private var model: AppModel
    let result: CheckResult

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 9) {
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text("MacPulse")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                }

                Text(result.modelName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 7) {
                    Label("macOS \(result.osVersion)", systemImage: "apple.logo")
                    Text("·").foregroundStyle(.quaternary)
                    Label(L10n.t("dashboard.upTime", result.uptime), systemImage: "clock")
                    Text("·").foregroundStyle(.quaternary)
                    Text(L10n.t("dashboard.checked", relative(result.date)))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button {
                model.showScoreBreakdown.toggle()
            } label: {
                ScoreRing(score: result.score, label: result.scoreLabel)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Health score \(result.score) of 100, \(result.scoreLabel). Click to toggle score breakdown.")

            VStack(spacing: 7) {
                HStack(spacing: 6) {
                    Button {
                        model.runCheck()
                    } label: {
                        HStack(spacing: 6) {
                            if model.isChecking {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(model.isChecking ? L10n.t("dashboard.checking") : L10n.t("dashboard.checkNow"))
                        }
                        .frame(minWidth: 108)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Theme.accent)
                    .disabled(model.isChecking)
                    .accessibilityLabel(model.isChecking ? "Checking system health…" : "Run system health check now")

                    Button {
                        model.showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel("Open MacPulse Settings")
                }

                Text(model.dailyCheck ? L10n.t("dashboard.dailyAt", model.formattedScheduleTime) : L10n.t("dashboard.dailyCheckOff"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .card()
    }
}

struct ScoreRing: View {
    let score: Int
    let label: String

    private var color: Color {
        if score >= 85 { return Theme.good }
        if score >= 70 { return Theme.accent }
        if score >= 50 { return Theme.warn }
        return Theme.bad
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 9)

            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100)
                .stroke(
                    AngularGradient(colors: [color, color.opacity(0.55), color], center: .center),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: -1) {
                Text("\(score)")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("score")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
        .frame(width: 84, height: 84)
        .help(label)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Health score \(score) out of 100, \(label)")
    }
}

// MARK: - Score breakdown

struct ScoreBreakdownView: View {
    @EnvironmentObject private var model: AppModel
    let subscores: [Subscore]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(L10n.t("dashboard.scoreBreakdown.title"), systemImage: "chart.bar.xaxis")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Done") {
                    model.showScoreBreakdown = false
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(Theme.accent)
            }

            Divider()

            VStack(spacing: 8) {
                ForEach(subscores) { item in
                    HStack {
                        HStack(spacing: 6) {
                            if item.points == 0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.good)
                                    .font(.system(size: 12))
                            } else {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(item.points >= 15 ? Theme.bad : Theme.warn)
                                    .font(.system(size: 12))
                            }
                            Text(item.title)
                                .font(.system(size: 12, weight: .medium))
                        }
                        Spacer()
                        Text(item.note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(item.points == 0 ? "0 pts" : "-\(item.points) pts")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(item.points == 0 ? Theme.good : (item.points >= 15 ? Theme.bad : Theme.warn))
                            .frame(width: 55, alignment: .trailing)
                    }
                }
            }
        }
        .card()
    }
}

// MARK: - History

struct Sparkline: View {
    /// Oldest to newest; the caller passes the stored history (newest first).
    let scores: [Int]

    var body: some View {
        GeometryReader { geometry in
            let values = scores.reversed().map(Double.init)
            let minimum = values.min() ?? 0
            let maximum = values.max() ?? 100
            let span = max(1, maximum - minimum)

            Path { path in
                for (index, value) in values.enumerated() {
                    let x = values.count <= 1
                        ? geometry.size.width / 2
                        : geometry.size.width * CGFloat(index) / CGFloat(values.count - 1)
                    let y = geometry.size.height
                        - CGFloat((value - minimum) / span) * (geometry.size.height - 4)
                        - 2
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                Theme.accent,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityHidden(true)
    }
}

struct HistorySection: View {
    let history: [HistoryEntry]
    let change: HistoryChange
    let isEarlierDay: Bool

    private var deltaColor: Color {
        if change.scoreDelta > 0 { return Theme.good }
        if change.scoreDelta < 0 { return Theme.bad }
        return Color(nsColor: .secondaryLabelColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(L10n.t("history.title"), systemImage: "chart.xyaxis.line")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(L10n.t("history.subtitle", min(history.count, ScanHistory.limit)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Sparkline(scores: history.map(\.score))
                        .frame(height: 46)
                    HStack {
                        Text("\(history.last?.score ?? 0)")
                        Spacer()
                        Text("\(history.first?.score ?? 0)")
                    }
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%+d", change.scoreDelta))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(deltaColor)
                    Text("pts")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 78, alignment: .trailing)
            }

            Text(isEarlierDay ? L10n.t("history.sinceYesterday") : L10n.t("history.sinceLastCheck"))
                .font(.system(size: 12, weight: .semibold))
                .padding(.top, 2)

            Text(ScanHistory.summary(for: change))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }
}

// MARK: - Attention

struct AttentionView: View {
    let items: [String]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warn)
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("dashboard.worthALook"))
                    .font(.system(size: 13, weight: .semibold))
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•").foregroundStyle(Theme.warn)
                        Text(item)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.warn.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.warn.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Metric grid

struct SectionLabel: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 2)
    }
}

struct CountBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.warn)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.warn.opacity(0.15), in: Capsule())
        }
    }
}

struct MetricGrid: View {
    let result: CheckResult

    private let columns = [GridItem(.adaptive(minimum: 232), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            MetricCard(
                icon: "cpu",
                title: "CPU Load",
                value: String(format: "%.2f", result.load1),
                caption: "5m \(String(format: "%.2f", result.load5)) · 15m \(String(format: "%.2f", result.load15)) · \(result.cpuCores) cores",
                status: result.cpuStatus
            )
            MetricCard(
                icon: "memorychip",
                title: "Memory",
                value: "\(Int(result.memFreePct))% free",
                caption: String(format: "%.0f GB total · %.1f GB compressed · %.0f MB swap", result.memTotalGB, result.memCompressedGB, result.swapUsedMB),
                status: result.memoryStatus
            )
            MetricCard(
                icon: "internaldrive",
                title: "Storage",
                value: "\(Int(result.diskFreeGB)) GB free",
                caption: "\(Int(result.diskFreePct))% of \(Int(result.diskTotalGB)) GB available",
                status: result.diskStatus
            )
            MetricCard(
                icon: batterySymbol,
                title: "Battery",
                value: batteryValue,
                caption: batteryCaption,
                status: result.batteryStatus
            )
            MetricCard(
                icon: "thermometer.medium",
                title: "Thermals",
                value: "\(Int(result.kernelTaskCPU))%",
                caption: "kernel_task — CPU throttling indicator",
                status: result.thermalStatus
            )
            MetricCard(
                icon: "power",
                title: "Startup",
                value: "\(result.loginItems.count) login item\(result.loginItems.count == 1 ? "" : "s")",
                caption: "\(result.launchAgentCount) launch agents installed",
                status: result.startupStatus
            )
            MetricCard(
                icon: "display",
                title: "WindowServer",
                value: "\(Int(result.windowServerCPU))%",
                caption: "Compositing / display overhead",
                status: result.windowServerStatus
            )
            MetricCard(
                icon: "moon.zzz.fill",
                title: "Auto-sleep (AC)",
                value: result.acSleepMinutes <= 0 ? "Never" : "\(result.acSleepMinutes) min",
                caption: sleepCaption,
                status: result.sleepStatus
            )
        }
    }

    private var batteryValue: String {
        if result.batteryCondition == "No battery" {
            if let peripherals = result.peripherals, !peripherals.isEmpty {
                return "\(peripherals.count) accessory\(peripherals.count == 1 ? "" : "ies")"
            }
            return "No battery"
        }
        return "\(Int(result.batteryHealthPct))% health"
    }

    private var batteryCaption: String {
        let periphStr = (result.peripherals ?? []).map { "\($0.name): \($0.percent)%" }.joined(separator: " · ")
        if result.batteryCondition == "No battery" {
            if !periphStr.isEmpty {
                return periphStr
            }
            return "Desktop Mac — running on power"
        }
        if !periphStr.isEmpty {
            return "\(result.batteryCycles) cycles · \(periphStr)"
        }
        return "\(result.batteryCycles) cycles · \(result.batteryCondition) · \(result.batteryCharge)%"
    }

    private var sleepCaption: String {
        if let assertions = result.sleepAssertions, assertions.contains(where: { $0.process == "caffeinate" }) {
            return "Sleep blocked by caffeinate"
        }
        if let assertions = result.sleepAssertions, !assertions.isEmpty {
            return "\(assertions.count) sleep assertion\(assertions.count == 1 ? "" : "s") active"
        }
        return "Applies while on the power adapter"
    }

    private var batterySymbol: String {
        if result.batteryCondition == "No battery" { return "powerplug" }
        if result.charging { return "battery.100.bolt" }
        switch result.batteryCharge {
        case 0..<13: return "battery.0"
        case 13..<38: return "battery.25"
        case 38..<63: return "battery.50"
        case 63..<88: return "battery.75"
        default: return "battery.100"
        }
    }
}

struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let caption: String
    let status: Status

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(status.color)
                .frame(width: 30, height: 30)
                .background(
                    status.color.opacity(0.13),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)
                .padding(.top, 4)
                .help(statusTitle)
        }
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value). \(caption). Status: \(statusTitle)")
    }

    private var statusTitle: String {
        switch status {
        case .good: return "Good"
        case .warn: return "Watch"
        case .bad: return "Needs attention"
        }
    }
}

// MARK: - Fixes

struct FixesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if model.visibleFixes.isEmpty {
                HStack(spacing: 11) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.good)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nothing to fix")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Every automated check passed on this run.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
            } else {
                ForEach(Array(model.visibleFixes.enumerated()), id: \.element.id) { index, fix in
                    FixRow(fix: fix)
                    if index < model.visibleFixes.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }

            if !model.declinedFixes.isEmpty {
                Divider()
                DeclinedSection()
            }
        }
        .card(padded: false)
    }
}

struct FixRow: View {
    @EnvironmentObject private var model: AppModel
    let fix: FixSuggestion

    private var isActionable: Bool {
        fix.isActionable
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(fix.severity.color)
                .frame(width: 30, height: 30)
                .background(fix.severity.color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(fix.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(fix.severity.label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(fix.severity.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(fix.severity.color.opacity(0.14), in: Capsule())
                    Spacer(minLength: 6)
                    Text(fix.value)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text(fix.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !fix.command.isEmpty {
                    if model.showAdvancedCommands {
                        Text(fix.command)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color.primary.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                            )
                            .padding(.top, 1)
                    } else {
                        DisclosureGroup {
                            Text(fix.command)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Color.primary.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                )
                        } label: {
                            Text("Show command")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 1)
                    }
                }

                HStack(spacing: 8) {
                    if isActionable {
                        Button {
                            model.approve(fix)
                        } label: {
                            HStack(spacing: 5) {
                                if model.runningFixID == fix.id {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: fix.nativeAction == "quit" ? "xmark.circle" : "checkmark")
                                }
                                Text(model.runningFixID == fix.id
                                     ? "Running…"
                                     : (fix.nativeAction == "quit" ? "Quit App" : "Approve"))
                            }
                            .frame(minWidth: 74)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.good)
                        .controlSize(.small)
                        .disabled(model.runningFixID != nil)
                        .accessibilityLabel("Approve fix: \(fix.title)")
                    }

                    Button(isActionable ? "Decline" : "Dismiss") {
                        model.decline(fix)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.runningFixID != nil)
                    .accessibilityLabel("\(isActionable ? "Decline" : "Dismiss") fix: \(fix.title)")

                    if fix.admin {
                        Label("Asks for admin password", systemImage: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    } else if fix.nativeAction == "quit" {
                        Label("Sends a normal Quit request", systemImage: "hand.raised.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    } else if fix.undoCommand != nil {
                        Label("Can be undone", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var symbol: String {
        switch fix.id {
        case "battery": return "battery.0percent"
        case "disk": return "internaldrive.fill"
        case "thermal": return "thermometer.high"
        case "notifications": return "bell.badge.fill"
        case "sleep": return "moon.zzz.fill"
        case "purge": return "memorychip.fill"
        case "windowserver": return "display"
        default:
            if fix.id.hasPrefix("login-") { return "person.crop.circle.badge.xmark" }
            if fix.id.hasPrefix("brew-") { return "shippingbox.fill" }
            if fix.id.hasPrefix("helper-") { return "gearshape.2.fill" }
            if fix.id.hasPrefix("quit-") { return "xmark.circle.fill" }
            return "wrench.fill"
        }
    }
}

struct DeclinedSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        DisclosureGroup(isExpanded: $model.showDeclined) {
            VStack(spacing: 0) {
                ForEach(model.declinedFixes) { fix in
                    HStack(spacing: 8) {
                        Text(fix.title)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restore") { model.restore(fix) }
                            .buttonStyle(.link)
                            .font(.caption)
                    }
                    .padding(.vertical, 5)
                }

                HStack {
                    Spacer()
                    Button("Restore all") { model.restoreAll() }
                        .buttonStyle(.link)
                        .font(.caption)
                }
                .padding(.top, 4)
            }
            .padding(.top, 4)
            .padding(.leading, 4)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 11))
                Text("\(model.declinedFixes.count) declined")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
        .padding(14)
    }
}

// MARK: - Activity

struct ActivitySection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        DisclosureGroup(isExpanded: $model.showActivity) {
            VStack(spacing: 0) {
                ForEach(Array(model.activity.enumerated()), id: \.element.id) { index, item in
                    ActivityRow(item: item)
                    if index < model.activity.count - 1 {
                        Divider().padding(.leading, 46)
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                Text("Recent activity")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(model.activity.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { model.clearActivity() }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .card(padded: false)
    }
}

struct ActivityRow: View {
    @EnvironmentObject private var model: AppModel
    let item: ActivityItem

    private var color: Color {
        switch item.state {
        case .running: return Color(nsColor: .secondaryLabelColor)
        case .success: return Theme.good
        case .failure: return Theme.bad
        case .undone: return Theme.accentAlt
        }
    }

    private var symbol: String {
        switch item.state {
        case .running: return "hourglass"
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .undone: return "arrow.uturn.backward.circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    if item.state == .undone {
                        Text("UNDONE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.accentAlt)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.accentAlt.opacity(0.14), in: Capsule())
                    }
                    Spacer(minLength: 6)
                    Text(relative(item.date))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Text(item.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if item.state == .success, item.undoCommand != nil {
                Button("Undo") { model.undo(item) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.runningFixID != nil)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }
}

// MARK: - Processes

struct ProcessSection: View {
    let processes: [TopProcess]

    var body: some View {
        VStack(spacing: 8) {
            if processes.isEmpty {
                Text("No process data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(processes.prefix(6))) { process in
                    HStack(spacing: 10) {
                        Text(process.name)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.primary.opacity(0.07))
                                Capsule()
                                    .fill(barColor(process.cpu))
                                    .frame(width: max(3, geometry.size.width * min(1, process.cpu / 60)))
                            }
                            .frame(height: 5)
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(width: 120, height: 12)

                        Text(String(format: "%.1f", process.cpu))
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                    }
                }
            }
        }
        .card()
    }

    private func barColor(_ cpu: Double) -> Color {
        if cpu > 60 { return Theme.bad }
        if cpu > 25 { return Theme.warn }
        return Theme.accent
    }
}

// MARK: - Footer

struct Footer: View {
    @EnvironmentObject private var model: AppModel
    let result: CheckResult

    var body: some View {
        HStack(spacing: 14) {
            Toggle(isOn: Binding(
                get: { model.dailyCheck },
                set: { model.setDailyCheck($0) }
            )) {
                Label("Daily check at \(model.formattedScheduleTime)", systemImage: "calendar.badge.clock")
                    .font(.system(size: 11))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            Spacer()

            Button {
                model.showSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.link)
            .font(.system(size: 11))

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([SystemCheck.storeURL])
            } label: {
                Label("Data folder", systemImage: "folder")
            }
            .buttonStyle(.link)
            .font(.system(size: 11))

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.5.0")")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
}

// MARK: - Banner + loading

struct BannerView: View {
    let banner: Banner

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: banner.kind.icon)
            Text(banner.text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(banner.kind.color)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.13), radius: 10, y: 4)
    }
}

/// Shown when the app has no cached scan and is not checking. The error variant
/// explains a partial scan instead of leaving an empty window.
struct ErrorOrEmptyView: View {
    @EnvironmentObject private var model: AppModel

    private var hasError: Bool { model.lastError != nil }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasError ? "exclamationmark.triangle.fill" : "waveform.path.ecg.rectangle")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(hasError ? Theme.warn : Theme.accent)

            VStack(spacing: 6) {
                Text(hasError ? L10n.t("empty.errorTitle") : L10n.t("empty.title"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(model.lastError ?? L10n.t("empty.body"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            Button {
                model.runCheck()
            } label: {
                Label(L10n.t("common.checkNow"), systemImage: "arrow.clockwise")
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.large)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoadingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text(L10n.t("loading.title"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(L10n.t("loading.body"))
                .font(.caption)
                .foregroundStyle(.tertiary)
            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.bad)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helpers

func relative(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}
