#!/usr/bin/env bash
# upskill: pull the latest skills down AND make them live in your clients.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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

if ! git -C "$WORKDIR" pull -q --ff-only origin main 2>/dev/null; then
  echo "• You have local edits that aren't pushed yet — run a sync (push) first," >&2
  echo "  or run /upskill:doctor if this keeps happening." >&2
  exit 1
fi
echo "✓ Pulled latest skills into $WORKDIR"

# Make the pulled skills LIVE: refresh the installed plugin in each client.
# (git pull only updates the editable workspace; the agent loads from the plugin.)
if [ -z "${UPSKILL_SKIP_REFRESH:-}" ]; then bash "$SCRIPT_DIR/_refresh.sh"; fi
