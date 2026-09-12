#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${TMPDIR:-/tmp}/ai-plan-core-tests"
swiftc \
  "$ROOT/Planning/Models/DateKey.swift" \
  "$ROOT/Planning/Models/DomainModels.swift" \
  "$ROOT/Planning/Services/IconEngine.swift" \
  "$ROOT/Planning/Services/PlanEngine.swift" \
  "$ROOT/QA/CoreRegressionTests.swift" \
  -o "$BIN"
"$BIN"
rm -f "$BIN"
