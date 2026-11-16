## What changed

<!-- One or two sentences. Link the issue if there is one. -->

## Safety

- [ ] No fix runs without an explicit click.
- [ ] No force kill, and no Apple/system services are disabled.
- [ ] Reversible fixes have an undo command.
- [ ] New rules have a stable ID, plain-English copy and no network access.
- [ ] `AGENTS.md` is updated if behaviour, rules or state changed.

## Verification

- [ ] `./test.sh` succeeds with all unit tests passing.
- [ ] `./build.sh` succeeds with no warnings.
- [ ] `python3 Tools/verify-json.py` passes.
- [ ] Follows commit conventions (`<type>(<scope>): <subject>`) defined in `AGENTS.md` and `CONTRIBUTING.md`.
- [ ] UI checked at 920×640 and a larger window, light and dark.
- [ ] Tested on: <!-- e.g. M1 laptop, Intel desktop, or "dev machine only" -->
