#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-start}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

show_usage() {
  printf '%s\n' \
    'usage: ./script/build_and_run.sh [mode]' \
    '' \
    'Modes:' \
    '  start, run                 Start the Expo dev server' \
    '  --ios, ios                 Start Expo and open iOS' \
    '  --android, android         Start Expo and open Android' \
    '  --web, web                 Start Expo for web' \
    '  --dev-client, dev-client   Start in development-client mode' \
    '  --tunnel, tunnel           Start using tunnel transport' \
    '  --export-web, export-web   Export the web build' \
    '  --doctor, doctor           Run Expo diagnostics' \
    '  --help, help               Show this help'
}

resolve_expo_cmd() {
  if [[ -n "${EXPO_CLI:-}" ]]; then
    # shellcheck disable=SC2206
    EXPO_CMD=(${EXPO_CLI})
  elif [[ -f pnpm-lock.yaml ]] && command -v pnpm >/dev/null 2>&1; then
    EXPO_CMD=(pnpm exec expo)
  elif [[ -f yarn.lock ]] && command -v yarn >/dev/null 2>&1; then
    EXPO_CMD=(yarn expo)
  elif { [[ -f bun.lock ]] || [[ -f bun.lockb ]]; } && command -v bun >/dev/null 2>&1; then
    EXPO_CMD=(bunx expo)
  else
    EXPO_CMD=(npx expo)
  fi
}

run_doctor() {
  npx expo-doctor
}

resolve_expo_cmd

case "$MODE" in
  start|run) exec "${EXPO_CMD[@]}" start ;;
  --ios|ios) exec "${EXPO_CMD[@]}" start --ios ;;
  --android|android) exec "${EXPO_CMD[@]}" start --android ;;
  --web|web) exec "${EXPO_CMD[@]}" start --web ;;
  --dev-client|dev-client) exec "${EXPO_CMD[@]}" start --dev-client ;;
  --tunnel|tunnel) exec "${EXPO_CMD[@]}" start --tunnel ;;
  --export-web|export-web) exec "${EXPO_CMD[@]}" export --platform web ;;
  --doctor|doctor) run_doctor ;;
  --help|help) show_usage ;;
  *) show_usage >&2; exit 2 ;;
esac
