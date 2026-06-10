#!/usr/bin/env bash
# Upskill uninstall — removes the plugins from your local clients and deletes
# ~/.upskill (workspace clone, credentials, throttle stamp, trash).
#
# Your repos are NOT deleted — your skills stay safe on GitHub. The exact
# delete commands are printed at the end if you really want them gone.
#
# Usage: uninstall.sh [--yes]
set -uo pipefail

YES=0; [ "${1:-}" = "--yes" ] && YES=1
if [ "$YES" = 0 ]; then
  printf "Remove Upskill from this machine? Your GitHub repos are kept. [y/N] "
  read -r a; case "$a" in y|Y|yes) ;; *) echo "aborted."; exit 0;; esac
fi

# Unwire clients (best-effort; command names vary slightly across versions).
if command -v claude >/dev/null 2>&1; then
  for spec in upskill@upskill skills@upskill-skills; do
    claude plugin uninstall "$spec" >/dev/null 2>&1 || claude plugin remove "$spec" >/dev/null 2>&1 || true
  done
  for mkt in upskill upskill-skills; do
    claude plugin marketplace remove "$mkt" >/dev/null 2>&1 || true
  done
  echo "  • Claude Code: unwired"
fi
CODEX="$(command -v codex || true)"
[ -z "$CODEX" ] && [ -x "/Applications/Codex.app/Contents/Resources/codex" ] && CODEX="/Applications/Codex.app/Contents/Resources/codex"
if [ -n "$CODEX" ]; then
  for spec in upskill@upskill skills@upskill-skills; do
    "$CODEX" plugin remove "$spec" >/dev/null 2>&1 || true
  done
  for mkt in upskill upskill-skills; do
    "$CODEX" plugin marketplace remove "$mkt" >/dev/null 2>&1 || true
  done
  echo "  • Codex: unwired"
fi

rm -rf "$HOME/.upskill"
echo "  • removed ~/.upskill"

LOGIN="$(command -v gh >/dev/null 2>&1 && gh api user -q .login 2>/dev/null || echo '<you>')"
cat <<EOF

✓ Upskill removed from this machine. Your skills are still on GitHub.

  To also delete the repos (irreversible):
    gh repo delete $LOGIN/upskill-skills
    gh repo delete $LOGIN/upskill-shared
EOF
