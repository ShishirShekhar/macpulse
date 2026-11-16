# Support

MacPulse is a small open-source project. Before opening an issue:

1. Read the [README](README.md), especially **Install**, **Fixes** and
   **Permissions**.
2. Search [existing issues](https://github.com/ShishirShekhar/macpulse/issues)
   and [discussions](https://github.com/ShishirShekhar/macpulse/discussions).
3. If the app will not open, follow the Gatekeeper steps in the README. Releases
   are ad-hoc signed, not notarized, so macOS asks once.

## Where to ask

| Topic | Where |
|---|---|
| "How do I…", ideas, setups, general questions | [Discussions](https://github.com/ShishirShekhar/macpulse/discussions) |
| A reproducible bug or wrong suggestion | [Bug report](https://github.com/ShishirShekhar/macpulse/issues/new?template=bug_report.yml) |
| A new rule or feature | [Feature request](https://github.com/ShishirShekhar/macpulse/issues/new?template=feature_request.yml) |
| A vulnerability | [Private security advisory](https://github.com/ShishirShekhar/macpulse/security/advisories/new) — never a public issue |

## Diagnostics to include

- macOS version and Mac model (Apple menu → About This Mac).
- Whether the issue is in the dashboard, the score, a suggestion, running a fix,
  undo, the daily check, or installation.
- The relevant part of
  `~/Library/Application Support/MacPulse/last-check.json`.
- `MacPulse --check` output if the issue is headless-only.

Redact personal paths, hostnames and app names you do not want public.

## Supported versions

The latest GitHub release is supported. Because releases are unsigned, the
maintainer cannot provide Apple-blessed support or notarization guarantees until
a Developer ID is available.
