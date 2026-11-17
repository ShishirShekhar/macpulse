import SwiftUI

/// First-run explanation. It is shown before the first scan so the Automation
/// prompt for login items can never appear while the dashboard is still loading.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    OnboardingRow(
                        icon: "gauge.medium",
                        title: L10n.t("onboarding.reads.title"),
                        detail: L10n.t("onboarding.reads.body")
                    )

                    OnboardingRow(
                        icon: "lock.shield.fill",
                        title: L10n.t("onboarding.privacy.title"),
                        detail: L10n.t("onboarding.privacy.body")
                    )

                    OnboardingRow(
                        icon: "hand.raised.fill",
                        title: L10n.t("onboarding.permissions.title"),
                        detail: L10n.t("onboarding.permissions.body")
                    )

                    scheduleCard
                }
                .padding(24)
            }

            Divider()

            HStack(spacing: 12) {
                Button(L10n.t("onboarding.later")) {
                    model.completeOnboarding(scheduleDaily: false)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Spacer()

                Button {
                    model.completeOnboarding(scheduleDaily: model.onboardingScheduleDaily)
                } label: {
                    Text(L10n.t("onboarding.start"))
                        .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 640, height: 640)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Theme.accent.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "waveform.path.ecg.rectangle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 58, height: 58)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("onboarding.title"))
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text(L10n.t("onboarding.subtitle"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { model.onboardingScheduleDaily },
                set: { model.onboardingScheduleDaily = $0 }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t(
                        "onboarding.schedule.toggle",
                        model.formattedScheduleTime
                    ))
                    .font(.system(size: 13, weight: .semibold))
                    Text(L10n.t("onboarding.schedule.body"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct OnboardingRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accentAlt)
                .frame(width: 30, height: 30)
                .background(
                    Theme.accentAlt.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
