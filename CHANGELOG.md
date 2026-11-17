# Changelog

All notable changes to MacPulse are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Nothing yet.

## [1.2.0] - 2026-11-17

Phase 2 product polish: onboarding, history, opt-in menu bar and alerts, string
catalogue, and empty/error states.

### Added

- First-run onboarding that explains what MacPulse reads, the local-only privacy
  promise, the Automation and administrator prompts, and the daily schedule. The
  first scan now waits for the tour, so macOS never prompts while the dashboard
  is loading.
- Scan history of the last 30 checks in `history.json`, shown as a score sparkline
  with a "since yesterday" (or "since the last check") summary of score changes
  and new or cleared recommendations.
- Opt-in menu bar extra showing the latest score with Check Now, Open MacPulse
  and Quit actions. It is off by default and can be removed from Settings.
- Opt-in local notification when the score crosses a configurable threshold
  (default 70). Alerts use `UNUserNotificationCenter` only; nothing is uploaded.
- Localization scaffolding in `Sources/Strings.swift`: one English catalogue,
  `L10n.t(key, arguments)` templates, and a visible key fallback for missing text.
- Empty and error states for a missing cached scan or a partial set of readings,
  with a direct retry action.
- Settings sections for scan history, the menu bar extra, score alerts and a
  "show the welcome tour again" action.
- 82 new unit tests (144 total) covering history pruning and comparison, threshold
  alert policy, and the string catalogue.

### Changed

- `build.sh` links `UserNotifications` and reports version 1.2.0 (build 4).
- The headless `--check` path now appends to history and can post a local alert.
- `AGENTS.md` records Phase 2 as complete, the new files and the data written.

### Fixed

- Removed the startup race where the Automation prompt could appear over an
  unfinished dashboard; onboarding now gates the first scan.
- Guarded the `MenuBarExtra` insertion binding against no-op updates, which could
  re-enter the scene body and crash SwiftUI when the extra was already enabled.

## [1.1.1] - 2026-11-16

### Fixed

- Prevented running GUI apps from being mistakenly flagged as background helpers:
  LaunchServices synthetic job labels (`application.*`, `uikitapplication.*`) and
  updater processes (`*.ShipIt`) are now strictly protected, and LaunchAgents are
  only suggested if backed by an installed `.plist` file on disk.

## [1.1.0] - 2026-11-16

Phase 1 engine generalization, native settings, test suite, and scoring breakdown.

### Added

- Native Settings window (`⌘,` or via header/footer) with configurable daily scan
  schedule time picker, rule exclusions toggles, declined suggestions manager,
  advanced command preview toggle, and full data/preference reset.
- Interactive Score Breakdown view displaying exact deductions for all eight
  health categories (starts at 100).
- Modular probe architecture (`Sources/Probes/`) separating typed detection from rules:
  `CPUProbe`, `MemoryProbe`, `DiskProbe`, `BatteryProbe`, `StartupProbe`, `DisplayProbe`,
  and `SystemProbe`.
- Pure parsing and labelling helpers in `ProbeParsers.swift`.
- Comprehensive Command Line Tools-compatible test suite (`./test.sh`) with 62 unit
  tests covering parsers, rule applicability, and scoring against realistic fixtures.
- VoiceOver accessibility labels, hints, and keyboard shortcuts across all cards and
  action buttons.
- Packaging fallback (`Tools/pack-icns.py`) for environments with restricted `iconutil`.

### Fixed

- Support for Homebrew service names containing `@` (e.g. `postgresql@14`).
- Gated WindowServer animation suggestions strictly to interactive scans.
- Platform-aware battery scoring so desktop Macs without batteries are never penalized.

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
