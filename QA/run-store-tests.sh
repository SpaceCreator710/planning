#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QA_TEMP="$(mktemp -d)"
trap 'rm -rf "$QA_TEMP"' EXIT
sed '/^import StoreKit$/d; /^import SwiftUI$/d' "$PROJECT_ROOT/Planning/Store/AppStore.swift" > "$QA_TEMP/AppStore.swift"
swiftc -swift-version 6 \
  "$PROJECT_ROOT/Planning/Models/DateKey.swift" \
  "$PROJECT_ROOT/Planning/Models/DomainModels.swift" \
  "$PROJECT_ROOT/Planning/Services/IconEngine.swift" \
  "$PROJECT_ROOT/Planning/Services/PlanEngine.swift" \
  "$PROJECT_ROOT/Planning/Services/InsightsEngine.swift" \
  "$PROJECT_ROOT/Planning/Services/AIService.swift" \
  "$PROJECT_ROOT/QA/StoreTestDoubles.swift" \
  "$QA_TEMP/AppStore.swift" "$PROJECT_ROOT/QA/StoreRegressionTests.swift" \
  -o "$QA_TEMP/store-tests"
"$QA_TEMP/store-tests"
