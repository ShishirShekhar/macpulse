# Security policy

MacPulse is local-only: it has no server, no accounts, no telemetry and no network
code. The security surface is therefore the local scanning and fix engine.

## Please report privately

Do not open a public issue for a vulnerability. Use GitHub's
[private vulnerability reporting](https://github.com/ShishirShekhar/macpulse/security/advisories/new)
or contact the maintainer through the GitHub profile. Include:

- macOS version and Mac model
- the exact rule ID and command involved
- what an attacker could achieve
- steps to reproduce, with secrets redacted

You can expect an acknowledgement within a few days.

## In scope

- A fix that runs without explicit user approval.
- A rule that can disable or kill an Apple/system process, bypass SIP/FileVault/
  firewall/MDM, delete user data, or escape the documented admin flow.
- Command injection through app names, login-item names, service labels or paths.
- Any unexpected network access.
- Privilege escalation through the `osascript` admin helper.

## Out of scope

- Gatekeeper warnings caused by ad-hoc signing (no Developer ID yet).
- Issues that require an already-compromised admin account.
- macOS bugs unrelated to MacPulse.

## Safety invariants

The full list is in [AGENTS.md](AGENTS.md) §7. In short: local only, explicit
consent, reversible where possible, no force kill, no Apple/system services, no
security settings changed, no user files deleted.
