#!/usr/bin/env bash
# upskill: refresh the INSTALLED plugins in each local client so newly synced
# skills become live. Covers BOTH marketplaces:
#   • upskill         (the shared tooling plugin — platform updates)
#   • upskill-skills  (your personal skills plugin)
# Best-effort across whatever clients are installed; one failing must not
# abort the others, so no `set -e`.
set -uo pipefail

did=0

refresh_claude() {
  claude plugin marketplace update "$1" >/dev/null 2>&1 || true
  claude plugin update "$2@$1"          >/dev/null 2>&1 || true
}
refresh_codex() {
  "$CODEX" plugin marketplace upgrade "$1" >/dev/null 2>&1 || true
  "$CODEX" plugin add "$2@$1"              >/dev/null 2>&1 || true
}

# Claude Code (CLI / desktop)
if command -v claude >/dev/null 2>&1; then
  refresh_claude upskill upskill
  refresh_claude upskill-skills skills
  echo "  • Claude Code: plugins refreshed"
  did=1
fi

# Codex (CLI on PATH, else the Codex.app bundled binary)
CODEX="$(command -v codex || true)"
[ -z "$CODEX" ] && [ -x "/Applications/Codex.app/Contents/Resources/codex" ] && CODEX="/Applications/Codex.app/Contents/Resources/codex"
if [ -n "$CODEX" ]; then
  refresh_codex upskill upskill
  refresh_codex upskill-skills skills
  echo "  • Codex: plugins refreshed"
  did=1
fi

if [ "$did" = 1 ]; then
  echo "↻ Run /reload-plugins (Claude Code CLI) or restart the app to load updated skills (they install globally)."
else
  echo "  (no client CLI found — desktop apps pull on their own refresh, or update via the app's Plugins screen)"
fi
