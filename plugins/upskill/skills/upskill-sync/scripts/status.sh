#!/usr/bin/env bash
# upskill: show current skills version and whether you're ahead/behind your repo.
set -euo pipefail

CREDS="${UPSKILL_CREDENTIALS:-$HOME/.upskill/credentials}"
ENV_WORKDIR="${UPSKILL_WORKDIR:-}"

if [ ! -f "$CREDS" ]; then
  echo "✗ No Upskill credentials at $CREDS. Say \"set up upskill\" first." >&2
  exit 1
fi
# shellcheck source=/dev/null
. "$CREDS"
[ -n "$ENV_WORKDIR" ] && UPSKILL_WORKDIR="$ENV_WORKDIR"
WORKDIR="${UPSKILL_WORKDIR:-$PWD}"

if [ ! -d "$WORKDIR/.git" ]; then
  echo "✗ $WORKDIR is not a git working copy. Run /upskill:doctor." >&2
  exit 1
fi

git -C "$WORKDIR" fetch -q origin main
LOCAL="$(git -C "$WORKDIR" rev-parse HEAD)"
REMOTE="$(git -C "$WORKDIR" rev-parse origin/main)"
VER="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]+'/.claude-plugin/marketplace.json'))['plugins'][0]['version'])" "$WORKDIR")"
COUNT="$(find "$WORKDIR/plugins/skills/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"

echo "Upskill status"
echo "  workspace:      $WORKDIR"
echo "  skills:         $COUNT"
echo "  skills version: v$VER"
if [ "$LOCAL" = "$REMOTE" ]; then
  if git -C "$WORKDIR" status --porcelain | grep -q .; then
    echo "  state: ✎ unsynced local edits — say \"upskill sync\" to push them"
  else
    echo "  state: ✓ up to date"
  fi
else
  AHEAD="$(git -C "$WORKDIR" rev-list --count origin/main..HEAD)"
  BEHIND="$(git -C "$WORKDIR" rev-list --count HEAD..origin/main)"
  echo "  state: ↑${AHEAD} ahead  ↓${BEHIND} behind — say \"upskill sync\" to reconcile"
fi
