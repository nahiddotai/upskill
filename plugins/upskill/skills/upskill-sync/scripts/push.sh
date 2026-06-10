#!/usr/bin/env bash
# upskill: push local skill edits up to your personal upskill-skills repo, then
# make them live in your clients. Runs entirely locally. No model calls.
#
# Usage:
#   push.sh                       # push whatever changed in your workspace
#   push.sh <skill> [<skill>…]    # first import freshly-created skill(s), then push
#   push.sh --import <name|dir>   # (legacy alias; extra names also accepted)
#
# Guarantees:
#   • Lint gate: a malformed skill never propagates (name/description checked).
#   • Last-push-wins: concurrent pushes from other clients are rebased in
#     (your edits win on conflict); nothing is lost — git history keeps all.
#   • Import MOVES the source copy to ~/.upskill/trash so a skill is never
#     loaded twice from two locations.
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

: "${UPSKILL_REMOTE:?UPSKILL_REMOTE not set in credentials}"
if [ ! -d "$WORKDIR/.git" ]; then
  echo "✗ $WORKDIR is not a git working copy. Run /upskill:doctor." >&2
  exit 1
fi

SKILLS_ROOT="$WORKDIR/plugins/skills/skills"

# --- optional: import newly-created skill(s) into the workspace --------------
import_one() {
  local arg="$1" NAME SRC=""
  if [ -d "$arg" ] && [ -f "$arg/SKILL.md" ]; then
    NAME="$(basename "$arg")"; SRC="$(cd "$arg" && pwd)"
  else
    NAME="$arg"
    for d in "$HOME/.claude/skills/$NAME" "$HOME/.codex/skills/$NAME" \
             "$HOME/.agents/skills/$NAME" "$PWD/.claude/skills/$NAME"; do
      if [ -f "$d/SKILL.md" ]; then SRC="$d"; break; fi
    done
  fi
  if [ -z "$SRC" ]; then
    echo "✗ Couldn't find a skill named '$NAME' to import." >&2
    echo "  Looked in ~/.claude/skills, ~/.codex/skills, ~/.agents/skills, ./.claude/skills." >&2
    return 1
  fi
  case "$SRC" in "$SKILLS_ROOT"/*)
    echo "• '$NAME' is already in your Upskill workspace — nothing to import."; return 0;;
  esac
  rm -rf "${SKILLS_ROOT:?}/$NAME"; mkdir -p "$SKILLS_ROOT"
  cp -R "$SRC" "$SKILLS_ROOT/$NAME"
  # Move (don't copy) the source out of the way so the skill isn't loaded
  # twice. Recoverable from ~/.upskill/trash.
  local TRASH="$HOME/.upskill/trash/$(date -u +%Y%m%dT%H%M%SZ)-$NAME"
  mkdir -p "$(dirname "$TRASH")"
  mv "$SRC" "$TRASH"
  echo "• Imported '$NAME' from $SRC"
  echo "  (original moved to $TRASH so it isn't loaded twice — Upskill owns it now)"
}

for arg in "$@"; do
  case "$arg" in --import|-*) continue;; esac
  import_one "$arg"
done

# --- lint gate: never propagate a broken skill --------------------------------
if ! python3 "$SCRIPT_DIR/_lint.py" "$SKILLS_ROOT"; then
  echo "✗ Fix the skill(s) above, then sync again. Nothing was pushed." >&2
  exit 1
fi

# --- stage and bail early if nothing actually changed -------------------------
git -C "$WORKDIR" add -A
if git -C "$WORKDIR" diff --cached --quiet && git -C "$WORKDIR" diff --quiet HEAD -- 2>/dev/null; then
  echo "• Nothing to sync (no changes)."
  exit 0
fi
git -C "$WORKDIR" commit -q -m "upskill sync (pending)"

# --- last-push-wins: rebase in concurrent pushes, bump AFTER, then push -------
# Bumping after the rebase guarantees the version is strictly greater than
# whatever is on the remote, so every client sees an update.
TRIES=0
while :; do
  TRIES=$((TRIES + 1))
  if ! git -C "$WORKDIR" pull -q --rebase -X theirs origin main; then
    git -C "$WORKDIR" rebase --abort >/dev/null 2>&1 || true
    echo "✗ Couldn't reconcile with your repo automatically. Run /upskill:doctor." >&2
    exit 1
  fi
  NEWVER="$(python3 "$SCRIPT_DIR/_bump.py" "$WORKDIR")"
  git -C "$WORKDIR" add -A
  git -C "$WORKDIR" commit -q --amend -m "upskill sync → v$NEWVER ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
  if git -C "$WORKDIR" push -q origin HEAD:main 2>/dev/null; then break; fi
  if [ "$TRIES" -ge 3 ]; then
    echo "✗ Push kept losing the race after $TRIES tries. Run /upskill:doctor." >&2
    exit 1
  fi
done

echo "✓ Synced to Upskill. Your skills are now v$NEWVER."
# Make your own new/edited skills live in this client too.
if [ -z "${UPSKILL_SKIP_REFRESH:-}" ]; then bash "$SCRIPT_DIR/_refresh.sh"; fi
