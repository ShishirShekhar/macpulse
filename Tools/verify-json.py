#!/usr/bin/env python3
"""Validate the JSON written by `MacPulse --check`."""
import json
import pathlib
import sys

if len(sys.argv) > 1:
    path = pathlib.Path(sys.argv[1]).expanduser()
else:
    path = (
        pathlib.Path.home()
        / "Library/Application Support/MacPulse/last-check.json"
    )

if not path.exists():
    print(f"missing: {path}", file=sys.stderr)
    sys.exit(1)

data = json.loads(path.read_text())

required = [
    "date", "model", "osVersion", "cpuCores", "memTotalGB", "diskFreeGB",
    "diskTotalGB", "batteryCondition", "topProcesses", "fixes", "score",
]
missing = [key for key in required if key not in data]
if missing:
    print(f"missing keys: {', '.join(missing)}", file=sys.stderr)
    sys.exit(1)

score = data["score"]
if not isinstance(score, int) or not 0 <= score <= 100:
    print(f"invalid score: {score!r}", file=sys.stderr)
    sys.exit(1)

if not isinstance(data["fixes"], list):
    print("fixes must be a list", file=sys.stderr)
    sys.exit(1)

for fix in data["fixes"]:
    for key in ("id", "title", "detail", "severity", "command", "admin", "value"):
        if key not in fix:
            print(f"fix {fix.get('id', '?')} missing {key}", file=sys.stderr)
            sys.exit(1)

print(f"ok — score {score}, {len(data['fixes'])} suggestion(s), {data['model']}")
