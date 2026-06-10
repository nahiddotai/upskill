#!/usr/bin/env bash
# upskill: one-button reconcile — save my edits UP, get everyone's latest DOWN,
# then make it all live. Safe order (push before pull avoids cache clobber).
# Optionally pass a freshly-created skill name to import it first.
#   reconcile.sh                # sync everything
#   reconcile.sh <skill-name>   # import a new skill, then sync
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export UPSKILL_SKIP_REFRESH=1          # refresh once at the end, not per-step
bash "$SCRIPT_DIR/push.sh" "$@"
bash "$SCRIPT_DIR/pull.sh"
unset UPSKILL_SKIP_REFRESH
bash "$SCRIPT_DIR/_refresh.sh"
