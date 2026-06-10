#!/usr/bin/env bash
# upskill: list skills that exist in local client dirs but are NOT in your
# synced library yet — candidates for import. Read-only; prints one per line:
#   <name>\t<path>
# Prints nothing (exit 0) when there's nothing new.
set -euo pipefail

CREDS="${UPSKILL_CREDENTIALS:-$HOME/.upskill/credentials}"
[ -f "$CREDS" ] && . "$CREDS" || true
WORKDIR="${UPSKILL_WORKDIR:-$PWD}"
SKILLS_ROOT="$WORKDIR/plugins/skills/skills"

for base in "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.agents/skills" "$PWD/.claude/skills"; do
  [ -d "$base" ] || continue
  for d in "$base"/*/; do
    [ -f "$d/SKILL.md" ] || continue
    [ -L "${d%/}" ] && continue                  # skip symlinks (managed elsewhere)
    n="$(basename "$d")"
    [ -d "$SKILLS_ROOT/$n" ] && continue          # already synced
    printf '%s\t%s\n' "$n" "${d%/}"
  done
done
