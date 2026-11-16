# Changelog

All notable changes to MacPulse are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Planned for future releases: scan history with a score trend (last 30 scans),
first-run onboarding with permission explanation, menu bar extra, and localization.

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
