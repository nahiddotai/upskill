#!/usr/bin/env bash
# Launcher for the Upskill auto-sync MCP server.
#
# The desktop app (and any client) launches plugin MCP servers at startup — which
# is the one general, automatic entry point plugins get on clients that DON'T run
# SessionStart hooks. We use it to trigger a throttled skill refresh with zero
# per-skill config. This launcher just guarantees a sane PATH (so the bundled
# refresh can find `claude`/`git`/`codex`) and then execs the stdio server.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)" || DIR="."
PY="$(command -v python3 || echo /usr/bin/python3)"
exec "$PY" "$DIR/autosync_server.py"
