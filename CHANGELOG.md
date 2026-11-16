# Changelog

All notable changes to MacPulse are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Planned for the next releases: a Settings window (schedule time, exclusions,
declined fixes, data reset), scan history with a score trend, first-run
onboarding, accessibility/VoiceOver pass, unit tests for the parsers and rule
engine, and localization scaffolding.

## [1.0.0] - 2026-11-16

First public release. Universal binary for Apple Silicon and Intel, macOS 13 or
newer, local only.

### Added

- Native SwiftUI dashboard with a 0–100 score, eight metric cards, a "Worth a
  look" strip, recommended fixes, recent activity and top processes.
- Device-aware engine (`DeviceProfile`) for Apple Silicon M1–M4 and Intel, laptops
  and desktops, with or without a battery.
- Declarative rule catalogue: battery service, low disk, inactive-memory purge,
  Notification Center reset, short sleep timer, thermal throttling,
  WindowServer load, busy GUI apps, running Homebrew services, third-party
  background helpers and login items.
- Explicit Approve/Decline for every fix, persisted decline list with restore,
  exact command preview, per-fix output log and automatic re-scan.
- Undo for reversible fixes directly from Recent Activity.
- Graceful app Quit suggestions via `NSRunningApplication.terminate()`; MacPulse
  never force-kills an app or targets Apple/system processes.
- Daily headless scan at 09:00 through a per-user LaunchAgent.
- Hard command timeouts, C-locale parsing and admin prompts only through the
  standard macOS password dialog.
- Zero telemetry, analytics, identifiers or network calls.
- GitHub Actions build workflow, unsigned release workflow with optional
  Developer ID signing/notarization, issue and PR templates, security policy and
  MIT license.
