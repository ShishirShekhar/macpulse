# MacPulse

[![Build](https://github.com/ShishirShekhar/macpulse/actions/workflows/build.yml/badge.svg)](https://github.com/ShishirShekhar/macpulse/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/ShishirShekhar/macpulse?sort=semver)](https://github.com/ShishirShekhar/macpulse/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ShishirShekhar/macpulse/total)](https://github.com/ShishirShekhar/macpulse/releases)
[![License: MIT](https://img.shields.io/github/license/ShishirShekhar/macpulse)](LICENSE)
![Platform: macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

A small, native macOS health dashboard. It checks your Mac, explains what is
slowing it down in plain language, and offers **one-click fixes that you approve
or decline**. It scans daily in the background and can be run manually at any
time.

- Native SwiftUI — no Electron, no runtime dependencies, ~2.7 MB
- Universal binary: Apple Silicon (M1–M4) and Intel, macOS 13 Ventura or newer
- Works on laptops and desktops, with or without a battery
- **No telemetry, no analytics, no network calls** — everything stays on your Mac
- Daily scan at 09:00 via a per-user LaunchAgent; manual scan with **Check Now** (⌘R)

## Install

### Download a release

1. Download `MacPulse-vX.Y.Z.zip` from the
   [Releases](https://github.com/ShishirShekhar/macpulse/releases) page.
2. Unzip it and move `MacPulse.app` to `/Applications`.
3. Releases are ad-hoc signed, not notarized (no Apple Developer Program yet), so
   Gatekeeper asks once. Either **right-click the app → Open**, or run:

   ```bash
   xattr -dr com.apple.quarantine /Applications/MacPulse.app
   ```

   On macOS 15 and later you can also use **System Settings → Privacy & Security →
   Open Anyway**.

### Build from source

Requires macOS 13+ and the Command Line Tools (`xcode-select --install`). Xcode is
not needed.

```bash
git clone https://github.com/ShishirShekhar/macpulse.git
cd macpulse
./build.sh --install
```

`build.sh` compiles both architectures, renders the app icon, signs ad-hoc, copies
to `/Applications`, and launches it. Without `--install` it only builds into
`build/`.

## What the dashboard shows

| Card | Meaning |
|---|---|
| CPU Load | 1/5/15-minute load average vs. logical core count |
| Memory | Free percentage, compressed memory, swap used |
| Storage | Free space on the data volume |
| Battery | Health %, cycle count, condition, charge (hidden meaning on desktops) |
| Thermals | `kernel_task` CPU — the macOS throttling indicator |
| Startup | Login items + installed launch agents |
| WindowServer | Compositing overhead (usually animated tabs/pages) |
| Auto-sleep (AC) | Sleep timer while on the power adapter |

A 0–100 **score** summarises the result, and the "Worth a look" strip calls out
what needs attention.

## Fixes

Each suggestion has **Approve** and **Decline**:

- **Approve** runs the fix, shows the output, and re-runs the check so the row
  disappears when it worked.
- **Decline** hides the suggestion. Declined items collect in a collapsible
  section with **Restore** / **Restore all**.
- **Show command** reveals the exact shell command before you approve it.
- **Undo** appears in **Recent Activity** for reversible fixes such as the sleep
  timer, a Homebrew service, or a background helper.
- Fixes that need root raise the standard macOS administrator password dialog.
- Hardware issues (for example a failing battery) are advice only — MacPulse never
  pretends software can repair them.
- App-level rows send a **normal Quit request** through macOS. MacPulse never
  force-kills an app, and if an app refuses to quit because of unsaved work the
  activity row says so.

Generic fix catalogue: battery service, low disk, inactive-memory purge,
Notification Center reset, short sleep timer, thermal throttling, high
WindowServer load, a busy GUI app, a running Homebrew service, a third-party
background helper (VPN, VM, tablet, remote-access agent), and login items.

MacPulse never offers to disable Apple or system services.

## Daily background check

On first launch the app installs
`~/Library/LaunchAgents/com.macpulse.daily.plist`, which runs `MacPulse --check`
every morning at 09:00. The check is headless: it writes the result to disk and
exits without showing a window. Toggle it with the switch at the bottom of the
dashboard.

Logs: `~/Library/Logs/MacPulse.log`

## Data

`~/Library/Application Support/MacPulse/last-check.json` — the latest result.
The app opens this folder from the **Data folder** link in the footer.

Nothing is uploaded. There are no accounts, identifiers, crash reports or update
pings.

## Permissions

- **Admin password** — only when you approve a fix marked with a lock.
- **Automation (System Events)** — used to read and remove login items. macOS
  asks once; if you deny it, the rest of the app still works and the last known
  login-item list is kept.

## Uninstall

```bash
launchctl bootout "gui/$(id -u)/com.macpulse.daily" 2>/dev/null
rm -f ~/Library/LaunchAgents/com.macpulse.daily.plist
rm -rf /Applications/MacPulse.app
rm -rf ~/Library/Application\ Support/MacPulse
```

## Contributing

Read [AGENTS.md](AGENTS.md) — the single source of truth for architecture, current
state, safety rules, roadmap and decisions. `CLAUDE.md`, `GEMINI.md` and the other
agent files only point there.

Bug reports and pull requests are welcome. Please keep the safety invariants in
`AGENTS.md` §7 intact.

## Community

- [Discussions](https://github.com/ShishirShekhar/macpulse/discussions) — questions,
  ideas and setups.
- [Support](SUPPORT.md) — where to ask and what to include.
- [Contributing](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md).
- [Changelog](CHANGELOG.md) — release history.
- [Security policy](SECURITY.md) — report vulnerabilities privately, never in a
  public issue.
