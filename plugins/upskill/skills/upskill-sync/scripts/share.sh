#!/usr/bin/env bash
# upskill: publish ONE skill to your public upskill-shared repo and print a
# shareable link. Recipients install just that skill (fork-on-install); their
# edits go to their own library, never yours. Runs locally, no model calls.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CREDS="${UPSKILL_CREDENTIALS:-$HOME/.upskill/credentials}"
SKILL="${1:?usage: share.sh <skill-name>}"

[ -f "$CREDS" ] && . "$CREDS" || true
WORKDIR="${UPSKILL_WORKDIR:-$PWD}"

command -v gh >/dev/null || { echo "✗ GitHub CLI (gh) required to share." >&2; exit 1; }
LOGIN="$(gh api user -q .login)"
SHARED_REMOTE="${UPSKILL_SHARED_REMOTE:-https://github.com/$LOGIN/upskill-shared.git}"
SHARED_DIR="${UPSKILL_SHARED_DIR:-$HOME/.upskill/shared}"

[ -d "$WORKDIR/plugins/skills/skills/$SKILL" ] || {
  echo "✗ skill '$SKILL' not found in $WORKDIR/plugins/skills/skills" >&2
  echo "  (sync it first: \"upskill sync $SKILL\")" >&2; exit 1; }

# Ensure the public shared repo exists.
if ! gh repo view "$LOGIN/upskill-shared" >/dev/null 2>&1; then
  echo "• creating your public shared repo $LOGIN/upskill-shared …"
  gh repo create "$LOGIN/upskill-shared" --public -d "Skills $LOGIN shares publicly via Upskill" >/dev/null
fi

# Ensure a local clone, current with the remote.
if [ ! -d "$SHARED_DIR/.git" ]; then
  rm -rf "$SHARED_DIR"
  git clone -q "$SHARED_REMOTE" "$SHARED_DIR" 2>/dev/null || {
    git init -q -b main "$SHARED_DIR"; git -C "$SHARED_DIR" remote add origin "$SHARED_REMOTE"; }
fi
git -C "$SHARED_DIR" pull -q --ff-only origin main 2>/dev/null || true

VER="$(python3 "$SCRIPT_DIR/_share.py" "$SHARED_DIR" add "$SKILL" "$WORKDIR" "$LOGIN")"
git -C "$SHARED_DIR" add -A
git -C "$SHARED_DIR" commit -q -m "share: $SKILL v$VER"
git -C "$SHARED_DIR" push -q origin HEAD:main

APP_URL="${UPSKILL_APP_URL:-https://upskill-app.pages.dev}"
echo "✓ Shared '$SKILL' (v$VER) publicly."
echo "  Your page (share this): ${APP_URL%/}/u/$LOGIN"
echo "  GitHub:                 https://github.com/$LOGIN/upskill-shared/tree/main/plugins/$SKILL"
echo "  Recipients can install from the page, or paste to their agent:"
echo "    Add the plugin marketplace https://github.com/$LOGIN/upskill-shared and install the \"$SKILL\" plugin from it."
