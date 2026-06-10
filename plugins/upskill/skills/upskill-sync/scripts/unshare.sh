#!/usr/bin/env bash
# upskill: remove ONE skill from your public shared repo (revoke the link).
# Already-installed copies keep working; the skill stops being listed/installable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CREDS="${UPSKILL_CREDENTIALS:-$HOME/.upskill/credentials}"
SKILL="${1:?usage: unshare.sh <skill-name>}"

[ -f "$CREDS" ] && . "$CREDS" || true

command -v gh >/dev/null || { echo "✗ GitHub CLI (gh) required." >&2; exit 1; }
LOGIN="$(gh api user -q .login)"
SHARED_REMOTE="${UPSKILL_SHARED_REMOTE:-https://github.com/$LOGIN/upskill-shared.git}"
SHARED_DIR="${UPSKILL_SHARED_DIR:-$HOME/.upskill/shared}"

if ! gh repo view "$LOGIN/upskill-shared" >/dev/null 2>&1; then
  echo "• nothing shared yet (no $LOGIN/upskill-shared repo)."; exit 0; fi
if [ ! -d "$SHARED_DIR/.git" ]; then
  rm -rf "$SHARED_DIR"; git clone -q "$SHARED_REMOTE" "$SHARED_DIR"; fi
git -C "$SHARED_DIR" pull -q --ff-only origin main 2>/dev/null || true

python3 "$SCRIPT_DIR/_share.py" "$SHARED_DIR" remove "$SKILL" "${UPSKILL_WORKDIR:-$PWD}" "$LOGIN" >/dev/null
git -C "$SHARED_DIR" add -A
if git -C "$SHARED_DIR" diff --cached --quiet; then
  echo "• '$SKILL' was not shared."; exit 0; fi
git -C "$SHARED_DIR" commit -q -m "unshare: $SKILL"
git -C "$SHARED_DIR" push -q origin HEAD:main
echo "✓ Unshared '$SKILL'. It is no longer listed at github.com/$LOGIN/upskill-shared."
