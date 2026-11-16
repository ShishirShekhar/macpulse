# Contributing to MacPulse

Thanks for helping. MacPulse is a small, dependency-free SwiftUI app with a strong
safety contract. Read [AGENTS.md](AGENTS.md) first — it is the single source of
truth for architecture, state, rules and roadmap.

## Ground rules

- Keep the app buildable with the Command Line Tools alone. Do not add `@State`
  (the SwiftUI macro plugin is unavailable without Xcode) or Xcode-only features.
- No third-party runtime dependencies, no Electron, no web wrappers.
- No network code in the core. No analytics, identifiers or telemetry.
- Never add a fix that runs without an explicit click.
- Never force-kill an app, and never offer to disable Apple or system services.
- Every new rule needs: a stable ID, a plain-English explanation, a safe command
  (or no command), an admin flag, and an undo command when the action is
  reversible.
- Update `AGENTS.md` in the same change when behaviour, rules or state change.

## Build and test

```bash
./build.sh                # build into build/, run a headless scan
./build.sh --install      # install to /Applications and launch
python3 Tools/verify-json.py
```

For UI changes, verify the window at 920×640 and a larger size, in light and dark
mode, and check that status is never conveyed by colour alone.

## Pull requests

- One concern per pull request; imperative commit messages.
- Describe the user-visible effect and any change to the rule catalogue.
- Include the exact command a fix runs, and its undo path, in the description.
- Do not edit `build/` or `.DS_Store`.

## Reporting bugs

Use the bug report template. Include macOS version, Mac model, `MacPulse --check`
output, and whether the issue is in the UI, a rule, or a fix. Redact anything
personal.
