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

Before committing any change, verify that both the test suite and universal build succeed:

```bash
./test.sh                 # runs all unit tests with fixtures (275 tests)
./build.sh                # build into build/, run a headless scan
./build.sh --install      # optional: install to /Applications and launch
```

For UI changes, verify the window at 920×640 and a larger size, in light and dark
mode, and check that status is never conveyed by colour alone.

## Contributing health rules

MacPulse evaluates system health using declarative rules in `Sources/Rules.swift`. Community contributions for new diagnostic rules are welcomed. When adding a rule:

1. **Safety & privacy**:
   - Zero telemetry, zero external network calls.
   - User approval is mandatory: never run silent fixes or force-kill applications.
   - Never offer to disable system processes (`kernel_task`, `launchd`, Apple daemons).
   - Only request admin privileges when strictly necessary, and always provide an `undoCommand` if reversible.
2. **Implementation steps**:
   - **Probe**: If the rule requires new telemetry, add or extend a probe in `Sources/Probes/`. Telemetry extraction must use safe timeouts, `LC_ALL=C`, and typed sample values.
   - **Parser**: Write pure parsing logic in `Sources/Probes/ProbeParsers.swift`.
   - **Rule definition**: Append the rule logic in `Sources/Rules.swift`. Construct a `FixSuggestion` with stable ID, severity (`.high`, `.medium`, `.low`), and localized strings.
   - **Localization**: Add English strings to `Sources/Strings.swift` under `rule.<id>.title`, `rule.<id>.detail`, and `rule.<id>.value`.
   - **Settings**: Register the rule in `Sources/SettingsView.swift` under `availableExcludableRules` so users can toggle it.
   - **Tests & fixtures**: Add sample CLI outputs in `Tests/Fixtures/` and unit tests in `Tests/RunTests.swift`. Ensure `test.sh` and `build.sh` both pass.

## Commit message standards

MacPulse follows the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <short imperative summary>

[optional body explaining motivation and technical context]
```

- **Types:**
  - `feat`: User-facing features, rules, or settings.
  - `fix`: Bug fixes in rules, scoring, probes, or UI.
  - `refactor`: Internal restructuring with no user-visible behavior change.
  - `test`: Adding or updating test cases, fixtures, or runners.
  - `docs`: Documentation updates (`AGENTS.md`, `README.md`, `CHANGELOG.md`).
  - `chore`: Tooling, build scripts, CI workflows, `.gitignore`.
  - `perf`: Performance optimizations.
- **Scopes:** `probes`, `rules`, `scoring`, `ui`, `settings`, `tests`, `ci`, `shell`, `launchagent`, `model`.
- **Subject:** Imperative mood ("add", "fix", "update"), lowercase after the colon, no trailing period, max 72 characters.

### Change rules (what each commit must have)

- **Atomic commits:** Exactly one logical change per commit. Never mix refactoring, dependency updates, and feature changes.
- **The Green Gate:** Always run `./test.sh` and `./build.sh` before staging. Never commit failing code or broken tests.
- **No stray files:** Do not commit `build/`, `.build/`, `.DS_Store`, or log files.
- **Tests required:** New probes, rules, parsers, or scoring changes must include unit tests and fixtures in `Tests/`.
- **Keep `AGENTS.md` in sync:** Update `AGENTS.md` in the same commit whenever state, architecture, or rules change.

## Pull requests

- One concern per pull request; branch names follow `<type>/<kebab-case-name>`.
- Follow the commit conventions above.
- Describe the user-visible effect and any change to the rule catalogue.
- Include the exact command a fix runs, and its undo path, in the description.

## Reporting bugs

Use the bug report template. Include macOS version, Mac model, `MacPulse --check`
output, and whether the issue is in the UI, a rule, or a fix. Redact anything
personal.
