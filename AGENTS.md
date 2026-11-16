# AGENTS.md — MacPulse single source of truth

> **Read this file before touching anything.** It is the only maintained record of
> project state, decisions, and agent instructions. `README.md` is for end users.
> `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md` and `.cursor/rules/*`
> are redirects — they must never duplicate content. If you learn something new,
> update **this file only**.

Last updated: 2026-11-16 · App version: 1.0 (development build) · Status: generalized engine, feature-complete for GitHub v1; not yet published.

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
- Admin fixes use the standard macOS password dialog via `osascript`.
- Earlier fixes proven on the dev machine: NotificationCenter reset, sleep timer,
  Homebrew service, vendor login helper, system VPN daemon, login items.

### Known bugs / incomplete

1. **First launch can prompt for Automation** (System Events) while the dashboard is
   still loading. Show onboarding before prompting (Phase 2).
2. **Spotlight field is semantically wrong.** `mdutil -s /` reports whether indexing
   is *enabled*, not whether it is *active*; hidden in the UI but still in the model.
3. **`windowServerCPU` is not scored in headless scans** because nothing is
   compositing. Interactive scans still score it above 45 %.
4. **Fixed 09:00 schedule**, no Settings window, no way to change time or exclusions.
5. **No tests, no CI, no git repository, no license** yet (next step).
6. **No localization**; parsing assumes English `top`/`vm_stat`/`pmset` output, but
   all commands force `LC_ALL=C` so translated output cannot leak in.
7. **Ad-hoc signing** means TCC permissions can reset after rebuilds, and downloaded
   releases trigger Gatekeeper until a Developer ID exists.
8. **No notarization** — no Apple Developer identity is installed
   (`security find-identity` → 0 valid).
9. **App-level Quit is graceful by design.** Apps with unsaved work can refuse; the
   activity row reports that instead of force killing.
10. **Helper detection is deliberately conservative**: only vendor-hinted labels or
    busy non-Apple agents are surfaced. Quiet unknown helpers are not offered.
11. **Homebrew detection requires Homebrew**; without `brew`, no service suggestions.
12. **`DeviceProfile` is not persisted** in `last-check.json`; the UI infers a desktop
    from the "No battery" condition.

---

## 3. Runtime architecture

```
Launcher.main()                         Sources/MacPulseApp.swift
├── "--check"  → SystemCheck.collect(interactive: false) → save JSON → exit(0)
└── otherwise  → MacPulseUI (SwiftUI App)
                 └── WindowGroup → ContentView
                     └── @StateObject AppModel      Sources/AppModel.swift
                         ├── result: CheckResult?   (Codable, cached to disk)
                         ├── runCheck()             background scan
                         ├── approve(fix)           Shell.run / Shell.admin / native quit
                         ├── undo(item)             reverse command
                         ├── decline/restore        persisted in UserDefaults
                         └── setDailyCheck()        LaunchAgent install/uninstall

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
| `Sources/SystemCheck.swift` | Probing, parsing, generic detectors, scoring, persistence |
| `Sources/Rules.swift` | Declarative rule catalogue and user-facing fix copy |
| `Sources/Models.swift` | `CheckResult`, `FixSuggestion`, `DeviceProfile`, `Status`, derived statuses |
| `Sources/ContentView.swift` | Entire UI (dashboard, cards, fixes, activity, footer, banner) |
| `Sources/Shell.swift` | Timed process execution, C locale, admin via osascript |
| `Sources/LaunchAgent.swift` | Writes/loads `com.macpulse.daily` plist |
| `Tools/MakeIcon.swift` | Renders the 1024 px icon with AppKit at build time |
| `build.sh` | Compile → bundle → icon → ad-hoc sign → optional install |
| `README.md` | End-user documentation only |

**Data written**

- `~/Library/Application Support/MacPulse/last-check.json` — latest `CheckResult`
- `~/Library/Logs/MacPulse.log` — headless scan output
- `~/Library/LaunchAgents/com.macpulse.daily.plist` — daily schedule
- `UserDefaults` (`com.macpulse.app`) — `declinedFixIDs`
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

**Dev environment:** MacBook Air M1 (MacBookAir10,1), 8 GB, macOS 27.0.1, Swift 6.4,
CLT-only, `gh` authenticated as `ShishirShekhar`, no codesigning identity, no git repo
yet. The machine's battery is failing — that is a **test fixture**, not a product
assumption.

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

**Protected labels:** `com.apple.*`, `com.macpulse.*`, `homebrew.*` and
`com.openssh.*` are never offered as helper fixes, even when busy.

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
   WindowServer is not scored in headless runs. Weights are documented in §5; fixtures
   are still missing.
7. ⬜ **Settings**: scan schedule (time picker), launch-at-login, rule exclusions,
   declined-fix management, reset data, "show advanced commands".
8. ✅ **Preview before approve**: expandable command preview, admin badge, native-quit
   label, and Undo for reversible fixes.
9. ⬜ **History**: keep the last 30 scans; show score trend; prune older data.
10. ⬜ **UI scale**: 920×640 and 1600×1200 verified manually; larger accessibility text
    and a full VoiceOver pass are still to do.
11. ⬜ **Onboarding**: explain what is read, what is never uploaded, permission prompts,
    and how the daily schedule works.
12. ✅ **No network code** in the core. Update checks, if added later, must be opt-in and
    isolated (direct-distribution build only).

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

- Repo: `ShishirShekhar/macpulse` (name pending final confirmation).
- License: **MIT**.
- Minimum macOS: **13 Ventura**; universal arm64 + x86_64.
- Bundle ID: `com.macpulse.app` placeholder until the first tagged release; changing it
  later resets TCC permissions, so finalize before v1.0.0.
- Contents: `Sources/`, `Tools/`, `Tests/`, `build.sh`, `AGENTS.md`, `README.md`,
  `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`, `.github/workflows/`, `.gitignore`.
- CI: macOS runner; build universal; run tests; upload the zipped `.app`.
- Release: tag → GitHub Release with a zipped `.app` and checksums.

**Signing reality:** there is no Apple Developer Program membership and no signing
identity on the dev machine, so releases are **ad-hoc signed, not notarized**. Users
who download a release will hit Gatekeeper; the README must give the exact
right-click → Open (or `xattr -dr com.apple.quarantine`) steps, or they can build from
source with `./build.sh --install`. The release workflow must be written so that
Developer ID signing + notarization can be enabled later by adding secrets, without
restructuring. Enrolling in the Developer Program is optional and deferred.

**App Store is explicitly out of scope** (user decision). Do not add sandbox/Lite
targets, App Store metadata, or store-specific code. The sandbox limitation table is
kept in §14 for historical context only.


---

## 9. Roadmap

### Phase 1 — Generalize the engine (v1.0)
- [x] Add `Shell` timeouts + cancellation; scan budget; UI never hangs.
- [x] Preserve cached login items during headless scans.
- [ ] Split `SystemCheck` into probes (`CPUProbe`, `MemoryProbe`, `DiskProbe`,
      `BatteryProbe`, `StartupProbe`, `DisplayProbe`) returning typed values.
- [x] Rule catalogue in `Rules.swift`; remove machine-specific IDs; add generic
      Homebrew-service, LaunchAgent and third-party helper detectors.
- [x] Platform model (`DeviceProfile`): chip, cores, laptop/desktop, battery present,
      macOS major version; battery advice is gated on it.
- [x] Desktop-safe scoring; WindowServer only scored in interactive scans. Subscores
      and fixture-backed validation are still to do.
- [ ] Settings window (schedule time, exclusions, declined fixes, data reset).
- [x] Command preview + undo for reversible fixes; Recent Activity list.
- [ ] Unit tests: parsers (top/vm_stat/pmset/ioreg/brew JSON) with fixtures; rule
      applicability; scoring. `swift test` or a headless test binary (CLT-only safe).
- [ ] Accessibility labels + keyboard navigation + larger text check.

**Acceptance:** clean build with no warnings; headless scan < 3 s on M1/8 GB;
a Mac without a battery never reports battery issues; no rule mentions a specific
user's apps. Tests are still missing, so "all tests pass" remains open.

### Phase 2 — Product polish (v1.1)
- [ ] First-run onboarding + permissions explained.
- [ ] Settings: schedule time, exclusions, declined-fix management, data reset.
- [ ] History (30 scans), trend sparkline, "what changed since yesterday".
- [ ] Menu bar extra with score (opt-in).
- [ ] Optional local notification when score drops below a threshold.
- [ ] Localization scaffolding (English first; strings in one catalogue).
- [ ] Dark/light and window-size QA; empty/error states.

### Phase 3 — GitHub release (next)
- [ ] `git init`, `.gitignore`, LICENSE, CONTRIBUTING, SECURITY, issue templates.
- [ ] CI build on macOS runners (tests to be added when the test target exists).
- [ ] Release workflow that works unsigned today and accepts Developer ID secrets later.
- [ ] Tag v1.0.0, publish zipped `.app` + checksums + release notes.

### Phase 4 — Release hardening
- [ ] Signing-ready release workflow (Developer ID + notarization behind secrets;
      works unsigned today).
- [ ] Zipped `.app` + checksums + release notes on GitHub Releases.
- [ ] Homebrew cask (optional, after first release).
- [ ] Gatekeeper instructions in README; support/security docs.

### Phase 5 — After launch
- [ ] More rules (Time Machine, backupd, Spotlight actual activity, DNS, SMB, MDM).
- [ ] Localized UI; community rule contributions.
- [ ] Optional opt-in update check for the direct build only.

---

## 10. Decisions needed

Only one remains:

1. **Bundle ID**: keep `com.macpulse.app` until the first tagged release, then decide
   (`io.github.shishirshekhar.macpulse` is the safe recommendation if no domain is
   owned). Changing it resets TCC permissions.

Resolved 2026-11-16: GitHub-only distribution, every feature, app-level fixes allowed,
no Apple Developer Program for now (unsigned releases), MIT license, macOS 13 minimum.

Do not start a refactor whose design depends on the bundle ID before it is final.

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
| _pending_ | Bundle ID finalized before v1.0.0 | TCC stability |

---

## 12. How agents should work

**Read order:** this file → the specific source file you will change → `git log` (once
a repo exists). Do **not** re-read the whole codebase to answer a state question; §2,
§5 and §9 should be enough. Keep them current when you change behavior.

**Change rules**

- One concern per commit; imperative commit messages (`Add rule engine`, not `stuff`).
- No third-party dependencies unless unavoidable; no Electron/web wrappers.
- Keep the app buildable with CLT-only: no `@State`, no Xcode-only macros.
- New rules require: unique ID, applicability predicate, plain-English copy, safe
  command (or none), admin flag, reversibility note, and a test fixture.
- Never add a fix that runs without a click. Never add network calls to the core.
- Update `AGENTS.md` §2/§5/§9/§11 in the same commit as the behavior change.
- Do not edit `build/` (generated) or `.DS_Store` (ignored).
- Do not change the user's machine state while developing. Test destructive paths in a
  VM or behind `--dry-run`.
- If a fact here is wrong, fix it here rather than adding a second doc.

**Definition of done**

1. `./build.sh` succeeds with no warnings.
2. Headless scan produces valid JSON on the dev machine.
3. UI loads cached data instantly, scan does not block the main thread.
4. New/changed rules have tests and fixtures.
5. Safety invariants in §7 hold; no new permission prompts without copy explaining them.
6. `AGENTS.md` updated.

**Style**

- Swift 5 language mode, macOS 13 availability, SwiftUI + AppKit only.
- `@MainActor` avoided; publish UI state on the main queue (current pattern).
- Copy is short, plain English, no jargon, no fear-mongering, no emoji in UI strings.
- Colors come from `Theme`; status is never conveyed by color alone.
- Prefer SF Symbols available on macOS 13.

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

