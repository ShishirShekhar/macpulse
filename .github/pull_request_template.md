## What changed

<!-- One or two sentences. Link the issue if there is one. -->

## Safety

- [ ] No fix runs without an explicit click.
- [ ] No force kill, and no Apple/system services are disabled.
- [ ] Reversible fixes have an undo command.
- [ ] New rules have a stable ID, plain-English copy and no network access.
- [ ] `AGENTS.md` is updated if behaviour, rules or state changed.

## Verification

- [ ] `./build.sh` succeeds.
- [ ] `python3 Tools/verify-json.py` passes.
- [ ] UI checked at 920×640 and a larger window, light and dark.
- [ ] Tested on: <!-- e.g. M1 laptop, Intel desktop, or "dev machine only" -->
