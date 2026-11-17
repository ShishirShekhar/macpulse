# Changelog

All notable changes to MacPulse are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.0] - 2026-11-17

### Added

- **100% End-to-End Localization**:
  - Full localization of all dashboard metrics, labels, cards, activity badges, and action buttons.
  - Complete translation of all 18 excludable diagnostic rule titles and descriptions in Settings across English, German, French, Spanish, and Japanese.
  - Total dictionary entries expanded to 242 keys per language.
- **Modular Rule Architecture (`DiagnosticRule`)**:
  - Decoupled `Rules.build` into composable `DiagnosticRule` implementations (`BatteryHealthRule`, `DiskSpaceRule`, `MemoryPurgeRule`, `TimeMachineRule`, `SleepAssertionsRule`, etc.).
  - Individual rule evaluation isolation and direct testing.
- **Privacy-Preserving Diagnostic Report**:
  - Dedicated "Copy Diagnostic Report" capability in Settings and Dashboard footer.
  - Produces formatted Markdown diagnostics covering system hardware, primary metrics, active recommendations, and top processes while strictly omitting personal identifiers, usernames, and file paths.
- Unit test suite expanded to **2,388 passing tests**.

## [1.6.0] - 2026-11-17

### Added

- **In-app UI Language Selector in Settings**:
  - Direct selection of display language across English, German (`de`), French (`fr`), Spanish (`es`), and Japanese (`ja`), alongside macOS system default (`system`).
  - Instant live re-rendering of all user interface copy upon switching without restarting the application.
  - Persisted user language preference across app restarts and headless background runs.
  - Reset integration: resetting all preferences in Settings restores default system language behavior.
  - Unit test suite expanded to **1,441 tests** covering language selection state, dictionary completeness, and fallbacks.

## [1.5.0] - 2026-11-17

### Added

- **Multi-language translation catalogues**:
  - Full translations for German (`de`), French (`fr`), Spanish (`es`), and Japanese (`ja`).
  - Automatic language resolution matching system preferences (`Locale.preferredLanguages`) with safe English fallback.
  - Modular dictionary architecture in `Sources/Translations/`.

### Fixed

- **Spotlight active indexing probe (Known Bug #1)**:
  - Replaced misleading `mdutil -s /` configuration check with live CPU monitoring of `mds` and `mdworker` processes.
  - Eliminates unnecessary shell invocation, improving scan speed and accuracy.
- Test suite expanded to **1,399 tests** validating translations and format specifiers across all supported languages.

## [1.4.0] - 2026-11-17

### Added

- **Phase 6 power & sleep intelligence**:
  - Sleep assertions inspector (`SleepProbe`): queries `pmset -g assertions` to identify processes holding wake-locks that prevent idle display or system sleep.
  - Actionable `caffeinate` termination fix (`sleep-caffeinate-<pid>`): terminates rogue background keep-awake processes via standard SIGTERM without admin rights.
  - Peripheral battery monitoring (`PeripheralProbe`): samples connected Bluetooth and Apple HID accessories (Magic Mouse, Magic Keyboard, Magic Trackpads, wireless headsets) via `ioreg -r -l -k BatteryPercent`.
  - Accessory battery warnings (`peripheral-battery-<slug>`): warns when connected accessory charge drops to ≤ 20% (medium severity) or ≤ 10% (high severity).
  - Desktop battery card enhancement: dynamically displays connected accessory battery levels on Macs without internal batteries (Mac mini, Mac Studio, iMac, Mac Pro).
  - Rule exclusions: added `sleep-caffeinate` and `peripheral-battery` to configurable rule toggles in Settings.
- Expanded unit test suite from 275 to **312 unit tests** with new fixtures and test coverage.

## [1.3.0] - 2026-11-17

### Added

- **Phase 4 hardening**: Homebrew Cask definition in `Casks/macpulse.rb` for one-line installation (`brew tap ShishirShekhar/macpulse && brew install --cask macpulse`).
- **Phase 5 diagnostic rules**:
  - Time Machine backup monitoring: detect missing backup disk (`timemachine-none`), flag backups older than 7 days with a reversible `tmutil startbackup` fix (`timemachine-stale`), and explain active `backupd` resource usage (`backup`).
  - Spotlight indexing activity: explains high CPU during initial indexing or updates without offering destructive kills (`spotlight`).
  - DNS responder fix: detects busy `mDNSResponder` and suggests an admin-gated DNS cache flush (`dns`).
  - Network shares: detects busy mounted SMB shares consuming `smbd` CPU (`smb`).
  - MDM enrollment notice: informs when a Mac is managed via Mobile Device Management, never touching profiles or configuration (`mdm`).
- **UI localization expansion**: all dashboard section headers, buttons, and status labels now use the central `L10n` catalogue.
- **Opt-in software updates**: isolated update check in `Settings → Software Updates` querying public GitHub Releases. Off by default with zero analytics or tracking.
- **Community rule guidelines**: added step-by-step documentation for adding new rules in `CONTRIBUTING.md`.
- Expanded unit test suite to 275 tests covering new rules, parsers, CLI fixtures, and version comparison logic.

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
