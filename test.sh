#!/bin/bash
# Builds and runs the MacPulse headless test runner
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
SDK="$(xcrun --show-sdk-path)"
DEPLOY_TARGET="13.0"
CACHE_DIR="${TMPDIR:-/tmp}/macpulse-module-cache"
mkdir -p "$CACHE_DIR" "$BUILD/bin"

# Collect non-UI sources needed for engine logic
TEST_SOURCES=(
  "$ROOT/Sources/Models.swift"
  "$ROOT/Sources/Shell.swift"
  "$ROOT/Sources/Rules.swift"
  "$ROOT/Sources/Scoring.swift"
  "$ROOT/Sources/Strings.swift"
  "$ROOT/Sources/Translations/German.swift"
  "$ROOT/Sources/Translations/French.swift"
  "$ROOT/Sources/Translations/Spanish.swift"
  "$ROOT/Sources/Translations/Japanese.swift"
  "$ROOT/Sources/History.swift"
  "$ROOT/Sources/ScoreAlert.swift"
  "$ROOT/Sources/UpdateCheck.swift"
  "$ROOT/Sources/Probes/ProbeValues.swift"
  "$ROOT/Sources/Probes/ProbeParsers.swift"
  "$ROOT/Sources/Probes/CPUProbe.swift"
  "$ROOT/Sources/Probes/MemoryProbe.swift"
  "$ROOT/Sources/Probes/DiskProbe.swift"
  "$ROOT/Sources/Probes/BatteryProbe.swift"
  "$ROOT/Sources/Probes/StartupProbe.swift"
  "$ROOT/Sources/Probes/DisplayProbe.swift"
  "$ROOT/Sources/Probes/BackupProbe.swift"
  "$ROOT/Sources/Probes/ManagementProbe.swift"
  "$ROOT/Sources/Probes/SleepProbe.swift"
  "$ROOT/Sources/Probes/PeripheralProbe.swift"
  "$ROOT/Sources/Probes/SystemProbe.swift"
  "$ROOT/Sources/SystemCheck.swift"
  "$ROOT/Tests/RunTests.swift"
)

echo "▸ Compiling test suite…"
swiftc -swift-version 5 -O -parse-as-library \
  -module-cache-path "$CACHE_DIR" \
  -Xcc -fmodules-cache-path="$CACHE_DIR" \
  -target "arm64-apple-macos${DEPLOY_TARGET}" \
  -sdk "$SDK" \
  -framework Foundation -framework AppKit \
  "${TEST_SOURCES[@]}" \
  -o "$BUILD/bin/macpulse-tests"

echo "▸ Running tests…"
"$BUILD/bin/macpulse-tests"
