#!/usr/bin/env bash
# SessionStart hook: throttled, best-effort auto-pull of the INSTALLED plugin so
# new skills appear without a manual /upskill:pull. Then ask Claude Code to
# re-scan skills so they're usable this session (reloadSkills).
#
# Safety: never touches your editable workspace (unpushed edits are safe), runs
# at most once per UPSKILL_REFRESH_INTERVAL seconds (default 4h) to keep session
# start fast, and is fully best-effort (never blocks or fails a session).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)" || SCRIPT_DIR="."
STAMP="$HOME/.upskill/.last_refresh"
INTERVAL="${UPSKILL_REFRESH_INTERVAL:-14400}"
NOW="$(date +%s 2>/dev/null || echo 0)"
LAST=0; [ -f "$STAMP" ] && LAST="$(cat "$STAMP" 2>/dev/null || echo 0)"
case "$NOW$LAST" in *[!0-9]*) NOW=0; LAST=0;; esac

if [ "$NOW" -eq 0 ] || [ $((NOW - LAST)) -ge "$INTERVAL" ]; then
  mkdir -p "$HOME/.upskill" 2>/dev/null || true
  [ "$NOW" -gt 0 ] && echo "$NOW" > "$STAMP" 2>/dev/null || true
  bash "$SCRIPT_DIR/_refresh.sh" >/dev/null 2>&1 || true
fi

# Ask Claude Code to re-scan skills this session (harmless/ignored elsewhere).
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","reloadSkills":true}}\n'
exit 0
