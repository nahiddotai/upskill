#!/usr/bin/env bash
# Throttled, silent, best-effort refresh of the installed Upskill plugin.
#
# This is the shared engine behind Upskill's AUTOMATIC sync triggers:
#   • the SessionStart hook   (hooks/hooks.json -> _hook_refresh.sh) — Claude Code CLI
#   • the auto-sync MCP server (mcp/autosync_server.py)              — clients that load
#                                                                      plugin MCP servers (CLI)
#   • pull-on-use (a `!` preamble in skills/upskill-sync/SKILL.md)   — every client,
#                                                                      incl. the desktop app
# (The desktop app loads Upskill's skills but not its hooks/MCP, so pull-on-use is
# the only trigger that fires there.) All call into the same throttle stamp so, no
# matter how many triggers fire, we pull at most once per UPSKILL_REFRESH_INTERVAL
# (default 4h). Fully best-effort
# and SILENT: never blocks, never errors out, no output on the throttled path,
# always exits 0.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)" || SCRIPT_DIR="."
STAMP="$HOME/.upskill/.last_refresh"
INTERVAL="${UPSKILL_REFRESH_INTERVAL:-14400}"
NOW="$(date +%s 2>/dev/null || echo 0)"
LAST=0; [ -f "$STAMP" ] && LAST="$(cat "$STAMP" 2>/dev/null || echo 0)"
case "$NOW$LAST" in *[!0-9]*) NOW=0; LAST=0;; esac

# Throttled: only refresh if we've never refreshed or the interval has elapsed.
if [ "$NOW" -eq 0 ] || [ $((NOW - LAST)) -ge "$INTERVAL" ]; then
  mkdir -p "$HOME/.upskill" 2>/dev/null || true
  [ "$NOW" -gt 0 ] && echo "$NOW" > "$STAMP" 2>/dev/null || true
  bash "$SCRIPT_DIR/_refresh.sh" >/dev/null 2>&1 || true
fi

exit 0
