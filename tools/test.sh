#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUA_BIN="${LUA_BIN:-lua}"
LUAC_BIN="${LUAC_BIN:-luac}"

cd "$ROOT_DIR"

for file in *.lua; do
    "$LUAC_BIN" -p "$file"
done

"$LUA_BIN" tests/scheduler_smoke.lua
bash -n tools/stage.sh
./tools/stage.sh >/tmp/better-event-reminders-stage.log

version="$(awk -F': ' '/^## Version:/{print $2; exit}' BetterEventReminders.toc)"
archive=".release/BetterEventReminders-${version}.zip"
test -f "$archive"

if unzip -Z1 "$archive" | grep -E '(^|/)(\.git|README|tools/|tests/|\.release)' >/dev/null; then
    echo "Unexpected repository files found in staged archive" >&2
    exit 1
fi

echo "all Better Event Reminders checks passed"
