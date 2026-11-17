# AGENTS.md — MacPulse single source of truth

> **Read this file before touching anything.** It is the only maintained record of
> project state, decisions, and agent instructions. `README.md` is for end users.
> `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md` and `.cursor/rules/*`
> are redirects — they must never duplicate content. If you learn something new,
> update **this file only**.

Last updated: 2026-11-17 · App version: 1.4.0 · Status: **Phase 1 through Phase 6 complete; v1.4.0** (<https://github.com/ShishirShekhar/macpulse/releases/tag/v1.4.0>).

---

## 1. Final goal

MacPulse is a **native, fast, private macOS health dashboard** that any Mac user can
install and understand in under a minute. It scans the machine, explains what is
slowing it down in plain language, and offers **one-click fixes that the user must
explicitly approve**. It checks itself once a day in the background and can be run
manually at any time.

**Success criteria**

- Runs on every Mac from macOS 13 upward: Apple Silicon M1–M4 and Intel, laptops and
  desktops, with or without a battery, 8 GB or 64 GB of RAM.
- First useful screen in under ~1 second from cached data; a full scan in under ~3 s.
- Zero telemetry, zero network calls, all data local.
- Every automated fix is explicit, scoped, auditable, and reversible where possible.
- Installable from GitHub (download or build from source) with every feature in one
  build. No App Store edition.
- No terminal knowledge required; no Homebrew or developer tools needed by users.

**Non-goals for v1**: antivirus, malware scanning, real-time always-on monitoring,
kernel extensions, cache/"junk" deletion, battery hardware repair, remote management,
or anything that silently changes system settings.

---

## 2. Current state (verified 2026-11-16)

### Done and verified

- Native SwiftUI app builds with **Command Line Tools only** (no Xcode).
- Universal binary (arm64 + x86_64), ad-hoc signed, ~2.7 MB `.app`.
- Custom programmatic app icon (teal→blue squircle + pulse line), full `.icns` set.
- Dashboard: score ring, 8 metric cards, "Worth a look" strip, recommended fixes,
  recent activity, top processes, footer controls. UI verified via screen capture + OCR.
- Daily background scan: per-user LaunchAgent `com.macpulse.daily` runs
  `MacPulse --check` at 09:00; verified with `launchctl kickstart` (runs=1, exit 0,
  log written, JSON updated).
- Headless mode writes `~/Library/Application Support/MacPulse/last-check.json`.
- Approve/Decline flow with persisted declined IDs, restore/restore-all, per-fix
  execution log, result banner, automatic re-scan after a successful fix.
- **Rule engine** (`Rules.build`) replaces the old machine-specific if-chain. Every
  suggestion has a stable ID, severity, plain-English copy, optional command, admin
  flag and optional undo command.
- **`DeviceProfile`** detects chip, logical/perf/efficiency cores, Apple Silicon,
  laptop vs desktop, battery presence, OS major version and RAM. A Mac without a
  battery never receives battery advice.
- **Generic detectors** replace the personal fixes:
  - `brew services list --json` (text fallback) for running Homebrew services;
  - `launchctl list` plus `/Library/LaunchDaemons` scans for third-party helpers,
    filtered by vendor hints and a protected-label list;
  - `NSWorkspace` maps busy `top` PIDs to real GUI apps for a normal Quit request.
- **Safety**: every command has a hard timeout (default 8 s, exit code 124), C locale,
  protected Apple/system labels, no force kill, admin only for system-domain changes.
- **Undo + command preview**: reversible fixes expose an undo command; Recent Activity
  has an Undo button; every shell fix can show its exact command before approval.
- **Login items are preserved** when the headless agent cannot ask for Automation
  permission, instead of being overwritten with an empty list.
- Full headless scan measured **2.77 s** on the M1 / 8 GB dev machine; UI stays
  responsive on a background queue.
- **Published v1.0.0** (2026-11-16): <https://github.com/ShishirShekhar/macpulse/releases/tag/v1.0.0>
  with `MacPulse-v1.0.0.zip` + `checksums.txt`. The downloaded artifact was verified:
  checksum OK, universal `x86_64 arm64`, ad-hoc signature intact, headless `--check`
  exits 0 and produces valid JSON.
- Admin fixes use the standard macOS password dialog via `osascript`.
- Earlier fixes proven on the dev machine: NotificationCenter reset, sleep timer,
  Homebrew service, vendor login helper, system VPN daemon, login items.

**Phase 2 (v1.2.0) added and verified**

- **First-run onboarding** explaining what is read, the privacy guarantee, the
  Automation/admin prompts, and the daily check. The first scan now starts only
  after the tour is dismissed, so macOS never prompts while the dashboard loads.
- **Scan history** of the last 30 checks in `history.json`, with a score sparkline,
  a "since yesterday" (or "since the last check") summary, and new/cleared fix names.
- **Opt-in menu bar extra** showing the latest score, Check Now, Open MacPulse and Quit.
- **Opt-in local score alert** when the score crosses a configurable threshold
  (default 70). Notifications are local `UNUserNotificationCenter` alerts only.
- **Localization scaffolding** in `Sources/Strings.swift`: one English catalogue,
  `L10n.t(key, args)` with a visible key fallback and tests for every shipped string.
- **Empty and error states** for no cached scan and partial readings, plus a
  Settings section for history, menu bar, notifications and re-running onboarding.
- **312 unit tests pass** via `./test.sh` (was 275 before Phase 6). CI runs
  the suite on every push and pull request.

**Phase 4 & Phase 5 added and verified**

- **Homebrew Cask definition** in `Casks/macpulse.rb` for one-line installation.
- **Expanded diagnostic rules**: Time Machine backup detection (`timemachine-none`,
  `timemachine-stale`, `backup`), Spotlight indexing activity (`spotlight`), DNS cache
  flushing (`dns`), SMB share monitoring (`smb`), and MDM enrollment notice (`mdm`).
- **Comprehensive UI localization**: Dashboard section headers, buttons, labels, and
  status copy are extracted to `Sources/Strings.swift` and resolved through `L10n`.
- **Opt-in software updates**: Isolated `Sources/UpdateCheck.swift` checks GitHub
  Releases when opted in. Off by default; zero telemetry or network calls in core.
- **Community rule contribution standards** documented in `CONTRIBUTING.md`.

**Phase 6 added and verified**

- **Sleep assertions inspector**: `pmset -g assertions` parser in `Sources/Probes/SleepProbe.swift`
  with actionable rule for terminating rogue `caffeinate` background processes (`kill <pid>`).
- **Peripheral battery monitoring**: `ioreg -r -l -k BatteryPercent` parser in
  `Sources/Probes/PeripheralProbe.swift` tracking connected Bluetooth and HID accessories
  (Magic Mouse, Magic Keyboard, Magic Trackpads) with advice warnings when battery drops ≤ 20%.
- **Desktop battery card enhancement**: Displays accessory charge levels even when no
  internal battery is present.

### Known bugs / incomplete

1. **Spotlight field is semantically wrong.** `mdutil -s /` reports whether indexing
   is *enabled*, not whether it is *active*; hidden in the UI but still in the model.
2. **`windowServerCPU` is not scored in headless scans** because nothing is
   compositing. Interactive scans still score it above 45 %.
3. **Localization is scaffolded, not translated.** All new Phase 2 copy lives in
   `L10n`; older dashboard strings are still inline English. Parsing assumes English
   `top`/`vm_stat`/`pmset` output, but every command forces `LC_ALL=C`.
4. **Ad-hoc signing** means TCC permissions can reset after rebuilds, and downloaded
   releases trigger Gatekeeper until a Developer ID exists.
5. **No notarization** — no Apple Developer identity is installed
   (`security find-identity` → 0 valid).
6. **App-level Quit is graceful by design.** Apps with unsaved work can refuse; the
   activity row reports that instead of force killing.
7. **Helper detection is deliberately conservative**: only vendor-hinted labels or
   busy non-Apple agents are surfaced. Quiet unknown helpers are not offered.
8. **Homebrew detection requires Homebrew**; without `brew`, no service suggestions.
9. **Notification permission is per user.** If it is denied in System Settings, the
   toggle reports the denial and stays off; MacPulse never re-prompts in a loop.
10. **The menu bar extra is off by default.** Enabling it from Settings inserts the
    `MenuBarExtra` scene; disabling removes it immediately.

---

## 3. Runtime architecture

```
Launcher.main()                         Sources/MacPulseApp.swift
├── "--check"  → collect → save last-check.json → HistoryStore.record()
│                → Notifications.postIfNeeded() → exit(0)
└── otherwise  → MacPulseUI (SwiftUI App)
                 ├── WindowGroup(id: "main") → ContentView
                 │   └── @StateObject AppModel      Sources/AppModel.swift
                 │       ├── result: CheckResult?   (Codable, cached to disk)
                 │       ├── history: [HistoryEntry] (last 30, history.json)
                 │       ├── runCheck()             background scan + history + alert
                 │       ├── approve(fix)           Shell.run / Shell.admin / native quit
                 │       ├── undo(item)             reverse command
                 │       ├── decline/restore        persisted in UserDefaults
                 │       ├── completeOnboarding()   installs agent, then first scan
                 │       └── setDailyCheck()        LaunchAgent install/uninstall
                 ├── MenuBarExtra (opt-in) → MenuBarContent
                 ├── Onboarding sheet → OnboardingView
                 └── Settings scene → SettingsView

SystemCheck.collect()                   Sources/SystemCheck.swift
├── sysctl (model, chip, P/E cores, load, memory, boot time)
├── memory_pressure, vm_stat, vm.swapusage
├── df, pmset, ioreg (battery), mdutil
├── top -l 2 (process CPU snapshot, last sample only)
├── osascript System Events (login items, UI mode only)
├── DeviceProfile + generic detectors (brew, launchctl, NSWorkspace)
└── Rules.build(context) → [FixSuggestion] → rescore() → CheckResult
```

**Files**

| Path | Responsibility |
|---|---|
| `Sources/MacPulseApp.swift` | Entry point, headless `--check`, window + menu commands |
| `Sources/AppModel.swift` | Observable state, scan orchestration, fix/undo execution, banners |
| `Sources/SystemCheck.swift` | Probe orchestration, persistence paths, `--check` entry |
| `Sources/Probes/*.swift` | Typed CPU, memory, disk, battery, display, startup, backup, MDM and system probes |
| `Sources/Scoring.swift` | Score weights, subscores and the `ScoreInput` boundary |
| `Sources/Rules.swift` | Declarative rule catalogue and user-facing fix copy |
| `Sources/Models.swift` | `CheckResult`, `FixSuggestion`, `DeviceProfile`, `Status`, derived statuses |
| `Sources/History.swift` | `HistoryEntry`, 30-scan pruning, change summary, `HistoryStore` |
| `Sources/ScoreAlert.swift` | Pure threshold-crossing policy for the optional alert |
| `Sources/Notifications.swift` | Local `UNUserNotificationCenter` post/clear helpers |
| `Sources/UpdateCheck.swift` | Opt-in, isolated GitHub Releases update check |
| `Sources/Strings.swift` | Single English string catalogue (`L10n`) for all user-facing copy |
| `Sources/ContentView.swift` | Dashboard, trend card, fixes, activity, empty/error states |
| `Sources/OnboardingView.swift` | First-run tour shown before the first scan |
| `Sources/MenuBarView.swift` | Opt-in `MenuBarExtra` content and score label |
| `Sources/SettingsView.swift` | Settings scene: schedule, exclusions, history, alerts, updates, reset |
| `Sources/Shell.swift` | Timed process execution, C locale, admin via osascript |
| `Sources/LaunchAgent.swift` | Writes/loads `com.macpulse.daily` plist |
| `Casks/macpulse.rb` | Homebrew Cask formula definition |
| `Tools/MakeIcon.swift` | Renders the 1024 px icon with AppKit at build time |
| `build.sh` | Compile → bundle → icon → ad-hoc sign → optional install |
| `test.sh` | Headless CLT-compatible test runner |
| `README.md` | End-user documentation only |

**Data written**

- `~/Library/Application Support/MacPulse/last-check.json` — latest `CheckResult`
- `~/Library/Application Support/MacPulse/history.json` — last 30 `HistoryEntry` values
- `~/Library/Logs/MacPulse.log` — headless scan output
- `~/Library/LaunchAgents/com.macpulse.daily.plist` — daily schedule
- `UserDefaults` (`com.macpulse.app`) — `declinedFixIDs`, `excludedRuleIDs`,
  `hasCompletedOnboarding`, `menubarEnabled`, `scoreNotificationsEnabled`,
  `scoreNotificationThreshold`, `scheduleHour`, `scheduleMinute`,
  `checkForUpdatesEnabled`, `lastUpdateCheckDate`
- `~/Library/Preferences/company.thebrowser.dia.plist` — **never touched** (read-only
  diagnostics of other apps are out of scope)

---

## 4. Build, run, inspect

```bash
cd MacPulse

./build.sh                # build into ./build/MacPulse.app, run a headless check
./build.sh --install      # also copy to /Applications and launch

# headless scan (same code path as the daily agent)
build/MacPulse.app/Contents/MacOS/MacPulse --check

# inspect results
cat ~/Library/Application\ Support/MacPulse/last-check.json | python3 -m json.tool

# agent status
launchctl print "gui/$(id -u)/com.macpulse.daily"
launchctl kickstart "gui/$(id -u)/com.macpulse.daily"

# verify the bundle
lipo -info build/MacPulse.app/Contents/MacOS/MacPulse
codesign -dv build/MacPulse.app
plutil -p build/MacPulse.app/Contents/Info.plist
```

**Toolchain constraint (important):** the dev machine has Command Line Tools but not
Xcode. SwiftUI's `@State` macro plugin (`SwiftUIMacros`) is missing, so `@State` fails
to compile. Use `@StateObject` / `ObservableObject` published properties instead, or
move local UI state into `AppModel`. This is why `showDeclined` lives in the model.

**Dev environment:** MacBook Air M1 (MacBookAir10,1), 8 GB, macOS 27.2.1, Swift 6.4,
CLT-only, `gh` authenticated as `ShishirShekhar`, no codesigning identity. The machine's
battery is failing — that is a **test fixture**, not a product assumption.

**Canonical working copy:** `~/Drive/Code/Projects/MacPulse` (moved 2026-11-16 from
`~/Documents/Default Project/MacPulse`; the git remote and history are unchanged).
Clone anywhere; only this machine's copy lives there.

---

## 5. Current rule catalogue

All rules return a `FixSuggestion` (`id`, `title`, `detail`, `severity`, `command`,
`admin`, `value`, optional `undoCommand`, optional `nativeAction`/`nativeTarget`).
Empty `command` with no native action means "advice only" — the UI shows only Dismiss.

| id | Trigger | Action | Admin | Notes |
|---|---|---|---|---|
| `battery` | device has a battery, health < 80 %, condition Service Recommended | none (hardware) | no | High below 60 % health |
| `disk` | free < 10 % or < 15 GB | none (never deletes files) | no | Advice: move files / empty Bin |
| `purge` | free RAM < 10 % or swap > 1 GB | `purge` | yes | High above 2 GB swap |
| `notifications` | NotificationCenter/usernoted > 5 % | `killall` both | no | Reversible by macOS restarting them |
| `sleep` | AC sleep 1–5 min | `pmset -c sleep 30 …` | yes | Undo restores the previous value |
| `thermal` | kernel_task > 25 % | none (advice) | no | High above 50 % |
| `windowserver` | WindowServer > 60 % (interactive scans) | none (advice) | no | Background animation/video |
| `quit-<bundle>` | a GUI app uses ≥ 60 % CPU | `NSRunningApplication.terminate()` | no | Graceful Quit only; never force kill |
| `brew-<service>` | Homebrew reports a started service | `brew services stop <name>` | no | Undo starts it again |
| `helper-<label>` | vendor match or busy non-Apple agent; system daemons checked | `launchctl bootout` + `disable` | system domain only | Undo re-enables + bootstraps the plist |
| `login-<name>` | AppleScript login items | delete via System Events | no | Not reversible; TCC sensitive |
| `timemachine-none` | no Time Machine backup destination configured | none (advice) | no | Low severity; links to System Settings |
| `timemachine-stale` | last backup finished ≥ 7 days ago | `tmutil startbackup` | no | Medium severity if ≥ 30 days; undo `tmutil stopbackup` |
| `backup` | backupd > 25 % CPU | none (advice) | no | Explains active backup copying changes |
| `spotlight` | mds / mdworker > 30 % CPU | none (advice) | no | Explains active indexing; pauses on user load |
| `dns` | mDNSResponder > 20 % CPU | `dscacheutil -flushcache; killall -HUP mDNSResponder` | yes | Safe cache flush clears stuck lookups |
| `smb` | smbd > 5 % CPU and SMB share mounted | none (advice) | no | Suggests disconnecting unneeded network mounts |
| `mdm` | Mac is enrolled in MDM | none (advice) | no | Informational only; never disables profiles |
| `sleep-caffeinate` | caffeinate holding sleep assertion | `kill <pid>` | no | Restores normal idle sleep |
| `peripheral-battery` | connected Bluetooth/HID peripheral battery ≤ 20 % | none (advice) | no | High below 10 % |

**Protected labels:** `com.apple.*`, `com.macpulse.*`, `homebrew.*`, `com.openssh.*`,
`org.openbsd.*`, running GUI applications (`application.*`, `uikitapplication.*`),
and Electron/Squirrel updaters (`*.ShipIt`) are never offered as helper fixes.
Furthermore, user launch agents are only offered if backed by a valid `.plist`
file on disk in `~/Library/LaunchAgents` or `/Library/LaunchAgents`.

**Scoring (current):** start at 100; −20 if load > 1.5× logical cores, −10 if
> 0.8×; −15 if free RAM < 10 % or swap > 1 GB, −8 if < 25 %; −15 if disk < 10 % free,
−7 if < 20 %; −25 if battery health < 60 %, else −10 if condition ≠ Normal (only when
a battery exists); −15/−5 for kernel_task > 30 %/> 15 %; −5 each for
NotificationCenter > 10 %, AC sleep ≤ 5 min, > 8 launch agents, and WindowServer
> 45 % **in interactive scans only**. App/helper/service fixes do not directly change
the score; the automatic re-scan reflects the result.

---

## 6. Generalization requirements

The engine is now device-generic; the remaining work is polish and test coverage.

**Requirements and status**

1. ✅ **Device-agnostic probes**: M1–M4 and Intel; MacBook vs Mac mini/Studio/iMac/Mac
   Pro; battery-less Macs never show a battery warning; core counts come from
   `hw.ncpu` with P/E counts recorded but load normalised per logical core.
2. ✅ **Locale-independent parsing**: `LC_ALL=C`, `LANG=C`, `LANGUAGE=C` for every
   command; machine-readable sources preferred (`brew services --json`).
3. ✅ **No hard-coded personal fixes.** Generic detectors now cover:
   - any Homebrew service that is running (`brew services list --json`) → offer stop;
   - user LaunchAgents consuming CPU, or vendor-labelled → offer disable with the
     label shown;
   - third-party VPN/VM/Docker helpers matched by vendor pattern, not exact ID;
   - system daemons checked with `launchctl print system/<label>` before offering.
4. ✅ **Rule engine, not if-chains.** `Sources/Rules.swift` holds one declarative
   catalogue with stable IDs, severity, plain-English copy, optional command, admin
   flag, undo command and native action. Still to do: split into testable `Rule`
   values.
5. ✅ **Every command has a hard timeout** (default 8 s; admin 300 s for the password
   dialog), partial results are acceptable, and the UI never blocks.
6. ✅ **Platform-aware scoring**: desktops are not penalised for having no battery and
   WindowServer is not scored in headless runs. Subscores and fixture-backed validation complete.
7. ✅ **Settings**: scan schedule (time picker), rule exclusions, declined-fix management,
   reset data, "show advanced commands" toggle.
8. ✅ **Preview before approve**: expandable command preview, admin badge, native-quit
   label, and Undo for reversible fixes.
9. ✅ **History**: keep the last 30 scans in `history.json`, prune older data, show a
   sparkline and a "since yesterday" change summary with new/cleared recommendations.
10. ✅ **UI scale & accessibility**: 920×640 and 1600×1200 verified; score breakdown
    and trend views added; VoiceOver labels and keyboard accessibility in place;
    empty/error states cover a missing or partial scan.
11. ✅ **Onboarding**: explains what is read, what is never uploaded, the Automation
    and admin prompts, and the daily schedule. It appears before the first scan.
12. ✅ **No network code** in the core. Update checks, if added later, must be opt-in and
    isolated (direct-distribution build only).
13. ✅ **Optional surfaces are opt-in**: menu bar extra and local score alerts default
    to off, use only local APIs, and can be turned off at any time in Settings.
14. ✅ **Localization scaffolding**: `L10n` holds one English catalogue with a visible
    key fallback; new Phase 2 surfaces read every string through it.

---

## 7. Safety & privacy invariants (never break)

- **Local only.** No analytics, crash reporting, identifiers, or network calls.
- **User consent is mandatory** for every change. No silent fixes, no auto-kill.
- Never disable SIP, FileVault, the firewall, MDM, or security updates.
- Never delete user files, caches, mail, photos, or browser data.
- Never modify accessibility/display settings (Reduce Motion, transparency) without
  an explicit user choice; they are not default fixes.
- Show the exact command before it runs and log everything that ran with output.
- Prefer reversible actions; if a fix cannot be undone, say so in the row.
- Admin rights only through the OS dialog, only for the specific command needed.
- System processes (`kernel_task`, `WindowServer`, `launchd`, `loginwindow`) are never
  killed or disabled.

---

## 8. Distribution strategy (decided 2026-11-16)

**GitHub only. Every feature stays in one build. No App Store edition.**

- Repo: <https://github.com/ShishirShekhar/macpulse> — public, MIT.
- License: **MIT** (`LICENSE`), copyright 2026 Shishir Shekhar.
- Minimum macOS: **13 Ventura**; universal arm64 + x86_64.
- Bundle ID: `com.macpulse.app` for the GitHub build. It only needs changing if
  distribution changes; doing so resets TCC permissions.
- Contents: `Sources/`, `Tools/`, `build.sh`, `AGENTS.md`, `README.md`, `LICENSE`,
  `CONTRIBUTING.md`, `SECURITY.md`, `.github/workflows/`, `.gitignore`, issue and PR
  templates.
- CI: `.github/workflows/build.yml` runs on `macos-latest`, builds universal, validates
  the headless JSON, verifies the bundle, and uploads `MacPulse.app` as an artifact.
  **Verified green on 2026-11-16** (52 s). `./test.sh` runs 144 tests on every push
  and pull request.
- Release: `.github/workflows/release.yml` runs on a `v*` tag, builds, optionally signs
  and notarizes when secrets exist, then publishes a zipped `.app` + `checksums.txt`.
- First release: tag **v1.0.0** published 2026-11-16 with assets
  `MacPulse-v1.0.0.zip` and `checksums.txt`, plus hand-written release notes. The
  workflow ran green (1 m 12 s). To cut a future release, tag `vX.Y.Z` and push the tag;
  keep `CFBundleShortVersionString` in `build.sh` in sync.
- **v1.2.0** published 2026-11-17 (`MacPulse-v1.2.0.zip` + `checksums.txt`, curated
  notes). Downloaded artifact verified: checksum OK, universal `x86_64 arm64`,
  ad-hoc signature intact, `CFBundleShortVersionString` 1.2.0 (build 4).
- **v1.3.0** published 2026-11-17: Phase 4 & Phase 5 release with Homebrew Cask,
  Time Machine, Spotlight, DNS, SMB, MDM rules, opt-in software updates,
  and expanded localization (build 5).

**Signing reality:** there is no Apple Developer Program membership and no signing
identity on the dev machine, so releases are **ad-hoc signed, not notarized**. Users
who download a release will hit Gatekeeper; README gives the exact right-click → Open
(or `xattr -dr com.apple.quarantine`) steps, or they can build from source with
`./build.sh --install`. The release workflow already accepts Developer ID and
notarytool secrets, so enrollment can be added later without restructuring.
Enrolling in the Developer Program is optional and deferred.

**App Store is explicitly out of scope** (user decision). Do not add sandbox/Lite
targets, App Store metadata, or store-specific code. The sandbox limitation table is
kept in §14 for historical context only.

### GitHub repository configuration (applied 2026-11-16)

- Description, homepage (`releases/latest`), 12 topics, Issues on, Discussions on,
  Projects and Wiki off.
- Merges: squash and rebase allowed, merge commits off; PR title + body for squash;
  auto-merge on, delete head branch on merge, update branch allowed.
- **Rulesets**: "Protect main" blocks deletion, force pushes and non-linear history;
  "Protect release tags" blocks deleting or moving `v*` tags. Repository admins can
  bypass so the solo maintainer is not locked out.
- Security: Dependabot alerts + security updates, secret scanning + push protection,
  private vulnerability reporting, `SECURITY.md` and `CODE_OF_CONDUCT.md`.
  Non-provider secret patterns and validity checks are not available on this plan
  (the API returned them disabled).
- Actions: allow selected actions only (GitHub-owned, verified creators, and
  `softprops/action-gh-release@*`), workflow default token is read-only, actions are
  pinned to commit SHAs and the repo **requires** SHA pinning (tag references are
  rejected), Dependabot updates the pins weekly.
- Workflows have `concurrency` and `timeout-minutes`; the build keeps artifacts 14 days.
- Community health: README badges, `CHANGELOG.md`, `SUPPORT.md`, issue-template
  config linking Discussions + private advisories, PR template.
- **Social preview**: `.github/social-preview.png` (1280×640, generated by
  `Tools/MakeSocialPreview.swift`) is uploaded and live —
  `usesCustomOpenGraphImage` is true and `og:image` serves
  `repository-images.githubusercontent.com/.../01512026-...`. GitHub has no API for
  this setting, so after changing the image it must be re-uploaded by hand in
  **Settings → General → Social preview** (the file input is
  `#repo-image-file-input`).


---

## 9. Roadmap

### Phase 1 — Generalize the engine (v1.0)
- [x] Add `Shell` timeouts + cancellation; scan budget; UI never hangs.
- [x] Preserve cached login items during headless scans.
- [x] Split `SystemCheck` into probes (`CPUProbe`, `MemoryProbe`, `DiskProbe`,
      `BatteryProbe`, `StartupProbe`, `DisplayProbe`) returning typed values.
- [x] Rule catalogue in `Rules.swift`; remove machine-specific IDs; add generic
      Homebrew-service, LaunchAgent and third-party helper detectors.
- [x] Platform model (`DeviceProfile`): chip, cores, laptop/desktop, battery present,
      macOS major version; battery advice is gated on it.
- [x] Desktop-safe scoring; WindowServer only scored in interactive scans. Subscores
      and fixture-backed validation complete.
- [x] Settings window (schedule time, exclusions, declined fixes, data reset).
- [x] Command preview + undo for reversible fixes; Recent Activity list.
- [x] Unit tests: parsers (top/vm_stat/pmset/ioreg/brew JSON) with fixtures; rule
      applicability; scoring, history, alerts and strings (`./test.sh` headless
      CLT-safe runner, 144 tests passing).
- [x] Accessibility labels + keyboard navigation + larger text check.

**Acceptance:** clean build with no warnings; headless scan < 3 s on M1/8 GB;
a Mac without a battery never reports battery issues; no rule mentions a specific
user's apps; all 144 unit tests pass.

### Phase 2 — Product polish (v1.2.0, done)
- [x] First-run onboarding + permissions explained before the first scan.
- [x] Settings: schedule time, exclusions, declined-fix management, data reset.
- [x] History (last 30 scans), trend sparkline, "what changed since yesterday".
- [x] Menu bar extra with score (opt-in, off by default).
- [x] Optional local notification when the score crosses a configurable threshold.
- [x] Localization scaffolding (English first; one `L10n` catalogue with key fallback).
- [x] Dark/light and window-size QA; empty/error states for missing or partial scans.
- [x] 144 unit tests via `./test.sh`; CI runs them on every push and pull request.

### Phase 3 — GitHub release (done)
- [x] `git init`, `.gitignore`, LICENSE, CONTRIBUTING, SECURITY, issue templates.
- [x] CI build on macOS runners, including `./test.sh` on every push and pull request.
- [x] Release workflow that works unsigned today and accepts Developer ID secrets later.
- [x] Push to <https://github.com/ShishirShekhar/macpulse> (public, MIT).
- [x] Tag v1.0.0, publish zipped `.app` + checksums + release notes.

### Phase 4 — Release hardening (done)
- [x] Signing-ready release workflow (Developer ID + notarization behind secrets;
      works unsigned today).
- [x] Zipped `.app` + checksums + release notes on GitHub Releases.
- [x] Homebrew cask (`Casks/macpulse.rb` for tap & one-line install).
- [x] Gatekeeper instructions in README; support/security docs.

### Phase 5 — After launch (done)
- [x] More rules (Time Machine, backupd, Spotlight actual activity, DNS, SMB, MDM).
- [x] Localized UI; community rule contributions.
- [x] Optional opt-in update check for the direct build only.

### Phase 6 — Power & Peripheral Intelligence (done)
- [x] Sleep assertions inspector (`pmset -g assertions`) in `SleepProbe` detecting rogue wake-locks.
- [x] Actionable `sleep-caffeinate-<pid>` rule to terminate forgotten keep-awake processes.
- [x] Peripheral battery monitoring in `PeripheralProbe` (`ioreg -r -l -k BatteryPercent`) for Magic Mouse, Keyboard, Trackpads, headsets.
- [x] `peripheral-battery-<slug>` warning rule when accessory battery drops to ≤ 20%.
- [x] Desktop battery card enhancement displaying connected accessories when no internal battery exists.
- [x] 312 unit tests pass via `./test.sh`.

---

## 10. Decisions needed

None. All launch decisions are resolved (2026-11-16): GitHub-only distribution, every
feature in one build, app-level quit suggestions allowed, no Apple Developer Program for
now (unsigned releases), MIT license, macOS 13 minimum.

**Bundle ID is final: `com.macpulse.app`.** It stays for the GitHub build because the
app is not distributed through any store; changing it later would only reset TCC
permissions and gain nothing. Revisit only if distribution changes (for example a
Developer ID rebrand), and do it before a tagged release if it ever changes.

---

## 11. Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-11-15 | Native SwiftUI, zero dependencies | Fast, small, universal, no runtime |
| 2026-11-15 | Local-only, no telemetry | Privacy is a product promise |
| 2026-11-15 | Daily scan via per-user LaunchAgent | Works when the app is closed; no daemon |
| 2026-11-15 | Ad-hoc signing for development | No developer identity available yet |
| 2026-11-16 | Single source of truth in `AGENTS.md` | Avoid duplicated, stale AI docs |
| 2026-11-16 | GitHub-only distribution, no App Store | Sandbox would remove every useful fix |
| 2026-11-16 | Every feature in one build; app-level quit suggestions allowed | User decision; keep one code path |
| 2026-11-16 | MIT license, macOS 13 minimum | Simplest reuse; broadest reach |
| 2026-11-16 | Unsigned releases until a Developer account exists | No identity on the machine; document Gatekeeper |
| 2026-11-16 | Generic rule catalogue + device profile | One engine for every Mac class |
| 2026-11-16 | Graceful app Quit as a native action | Powerful without force-killing or losing work |
| 2026-11-16 | Undo command + Recent Activity | Reversible actions build trust |
| 2026-11-16 | Conservative helper detection | Never offer to disable unknown/Apple services |
| 2026-11-16 | Bundle ID stays `com.macpulse.app` | No store distribution; avoids TCC resets |
| 2026-11-17 | Onboarding gates the first scan | macOS Automation prompt must not appear over a half-loaded dashboard |
| 2026-11-17 | Menu bar extra and score alerts are opt-in | Keep the default app quiet and permission-free |
| 2026-11-17 | History keeps 30 local scans | Enough for a trend without unbounded disk growth |
| 2026-11-17 | One `L10n` catalogue, English first | Future translations add a dictionary, not view edits |
| 2026-11-17 | Homebrew Cask formula in `Casks/macpulse.rb` | One-line install via standard brew tap |
| 2026-11-17 | Time Machine, Spotlight, DNS, SMB, MDM rules | Deeper diagnostic coverage without destructive kills |
| 2026-11-17 | Opt-in update check against GitHub API | Zero tracking, disabled by default, isolated in `Sources/UpdateCheck.swift` |
| 2026-11-17 | Full dashboard UI localized via `L10n` | Central catalogue for clean translation and community contributions |
| 2026-11-17 | Sleep assertions and peripheral battery probes | Non-intrusive wake-lock debugging and accessory battery warnings; 312 unit tests |

---

## 12. How agents and contributors should work (Commit & Change Standard)

Both AI agents and human contributors must follow these commit, change, and verification standards.

### Commit message format

Every commit must follow the Conventional Commits specification:

```
<type>(<scope>): <short imperative summary>

[optional body explaining motivation, technical details, and context]

[optional footer(s), e.g. Closes #12, References #34]
```

**Allowed types:**
- `feat`: A new user-facing dashboard feature, rule, or setting (e.g. `feat(settings): add scan time picker`).
- `fix`: A bug fix in rules, scoring, probes, or UI (e.g. `fix(rules): allow @ symbol in brew service names`).
- `refactor`: Code restructuring with no user-visible behavior change (e.g. `refactor(probes): split SystemCheck into typed probes`).
- `test`: Adding or updating test cases, fixtures, or test runner (e.g. `test(rules): add battery service fixtures`).
- `docs`: Documentation updates only (e.g. `docs: update AGENTS.md with Phase 1 status`).
- `chore`: Tooling, build scripts, CI workflow updates, `.gitignore` (e.g. `chore(ci): run test.sh in build workflow`).
- `perf`: Performance optimization (e.g. `perf(probe): cache sysctl lookups`).

**Allowed scopes (optional, recommended):**
`probes`, `rules`, `scoring`, `ui`, `settings`, `tests`, `ci`, `shell`, `launchagent`, `model`.

**Subject line rules:**
- Imperative, present tense: "add", "fix", "update", "prevent" (NOT "added", "adds", "fixing").
- Lowercase first character after the colon.
- No trailing period.
- Maximum 72 characters.

### Change rules (what each commit must contain)

1. **Atomic commits**: One commit represents exactly one logical unit of work. Never mix refactoring, formatting sweeps, and functional changes in the same commit.
2. **The "Green Gate" (Pre-commit check)**: Every commit MUST build cleanly (`./build.sh`) and pass all tests (`./test.sh`) before being committed. Never commit broken code or failing tests.
3. **No stray files**: Never commit `.build/`, `build/`, `.DS_Store`, temporary binaries, or logs. Always inspect `git status` before staging.
4. **Test accompaniment**: Any new probe, parser function, rule, or scoring change MUST include unit test coverage in `Tests/RunTests.swift` and fixtures in `Tests/Fixtures/`.
5. **Single source of truth**: If a change alters rules, architecture, scoring weights, or roadmap status, update `AGENTS.md` within the same commit.
6. **Toolchain discipline**: Never introduce `@State` into SwiftUI views (use `@StateObject` / `@EnvironmentObject` with an `ObservableObject` because Command Line Tools lack Xcode's `SwiftUIMacros`).
7. **Safety invariants hold**: No silent fixes, no force-killing apps, no disabling Apple/system daemons, and zero network calls.

### Definition of done

1. `./build.sh` succeeds with no warnings and universal binary intact.
2. `./test.sh` passes with 0 failures.
3. Headless scan (`MacPulse --check`) produces valid JSON on the dev machine.
4. UI loads cached data instantly, background scan does not block the main thread.
5. Safety invariants in §7 hold; no new permission prompts without copy explaining them.
6. `AGENTS.md` updated in the same commit.

### Style

- Swift 5 language mode, macOS 13 availability, SwiftUI + AppKit only.
- Avoid `@MainActor`; publish UI state on the main queue (`DispatchQueue.main.async`).
- Copy is short, plain English, no jargon, no fear-mongering, no emoji in UI strings.
- Colors come from `Theme`; status is never conveyed by color alone.
- Prefer SF Symbols available on macOS 13.
- VoiceOver accessibility labels and keyboard shortcuts on interactive controls.

**Testing checklist (manual, until automated)**

- MacBook with battery + desktop without battery (or simulated `batteryCondition`).
- 8 GB and 16 GB+ memory pressure paths.
- Headless `--check` with no GUI session.
- Approve a normal fix and an admin fix; verify log output and re-scan.
- Decline, restart, verify persistence; restore.
- Kill the app mid-scan; relaunch; verify cache.
- Light/dark, 920×640 and maximized; VoiceOver pass on the fixes list.

---

## 13. Glossary

- **Scan / check** — one `SystemCheck.collect()` producing a `CheckResult`.
- **Rule / fix** — a `FixSuggestion` with optional executable command.
- **Headless** — `MacPulse --check`, no UI, writes JSON, used by the daily agent.
- **Probe** — a single data source (CPU, memory, disk, battery, startup, display).
- **Lite** — the abandoned sandboxed App Store edition (public APIs only).

---

## 14. Historical: why the App Store was dropped

Recorded so nobody re-litigates it. App Sandbox forbids the mechanisms the product
depends on:

| Feature | Sandbox verdict |
|---|---|
| `top`, `vm_stat`, `ioreg`, `sysctl` via `Process` | not allowed (no arbitrary executables) |
| `launchctl`, `pmset`, `killall`, `brew` | not allowed |
| `purge` / admin fixes | not allowed (no privileged helper) |
| AppleScript to System Events | not allowed |
| Reading own JSON + UI + scheduling | allowed |
| Public APIs: `host_statistics`, `sysctl` via C, `IOKit` power sources, `ProcessInfo`, `NSWorkspace`, `SMAppService` | allowed |

A sandboxed build would have shipped diagnostics and deep links only. That was
rejected in favour of one full-featured GitHub build. Do not add sandbox code.

