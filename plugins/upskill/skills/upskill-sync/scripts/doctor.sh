#!/usr/bin/env bash
# upskill: diagnose the whole sync setup and print the exact fix for anything
# broken. Read-only (plus a git fetch). Always exits 0 — it's a report.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CREDS="${UPSKILL_CREDENTIALS:-$HOME/.upskill/credentials}"
OK=0; BAD=0

ok()  { echo "  ✓ $1"; OK=$((OK+1)); }
bad() { echo "  ✗ $1"; [ -n "${2:-}" ] && echo "      fix: $2"; BAD=$((BAD+1)); }

echo "Upskill doctor"
echo ""
echo "Prerequisites:"
command -v git >/dev/null 2>&1     && ok "git installed"     || bad "git not found" "install Xcode CLT / git"
command -v python3 >/dev/null 2>&1 && ok "python3 installed" || bad "python3 not found" "install python3"
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then ok "GitHub CLI authenticated"
  else bad "GitHub CLI not authenticated" "gh auth login"; fi
else
  bad "GitHub CLI (gh) not found" "brew install gh && gh auth login"
fi

echo ""
echo "Setup:"
WORKDIR=""
if [ -f "$CREDS" ]; then
  ok "credentials present ($CREDS)"
  # shellcheck source=/dev/null
  . "$CREDS"
  WORKDIR="${UPSKILL_WORKDIR:-}"
  [ -n "${UPSKILL_REMOTE:-}" ] && ok "remote: $UPSKILL_REMOTE" || bad "UPSKILL_REMOTE missing from credentials" "say \"set up upskill\" to rewrite them"
else
  bad "no credentials at $CREDS" "say \"set up upskill\""
fi

if [ -n "$WORKDIR" ] && [ -d "$WORKDIR/.git" ]; then
  ok "workspace is a git clone ($WORKDIR)"
  ACTUAL="$(git -C "$WORKDIR" remote get-url origin 2>/dev/null || echo '?')"
  if [ "$ACTUAL" = "${UPSKILL_REMOTE:-}" ]; then ok "workspace remote matches credentials"
  else bad "workspace remote is $ACTUAL, credentials say ${UPSKILL_REMOTE:-unset}" "say \"set up upskill\" to re-wire"; fi
  if git -C "$WORKDIR" fetch -q origin main 2>/dev/null; then
    ok "can reach the remote"
    LOCAL="$(git -C "$WORKDIR" rev-parse HEAD 2>/dev/null)"
    REMOTE="$(git -C "$WORKDIR" rev-parse origin/main 2>/dev/null)"
    if [ "$LOCAL" = "$REMOTE" ]; then ok "in sync with remote"
    else
      AHEAD="$(git -C "$WORKDIR" rev-list --count origin/main..HEAD 2>/dev/null || echo '?')"
      BEHIND="$(git -C "$WORKDIR" rev-list --count HEAD..origin/main 2>/dev/null || echo '?')"
      bad "↑$AHEAD ahead / ↓$BEHIND behind the remote" "say \"upskill sync\""
    fi
    git -C "$WORKDIR" status --porcelain 2>/dev/null | grep -q . \
      && bad "uncommitted local edits in the workspace" "say \"upskill sync\" to push them" \
      || ok "no stray uncommitted edits"
  else
    bad "cannot reach the remote" "check network / gh auth status"
  fi
elif [ -n "$WORKDIR" ]; then
  bad "workspace missing at $WORKDIR" "say \"set up upskill\" (it re-clones safely)"
fi

if [ -n "$WORKDIR" ] && [ -d "$WORKDIR/plugins/skills/skills" ]; then
  echo ""
  echo "Skills:"
  if python3 "$SCRIPT_DIR/_lint.py" "$WORKDIR/plugins/skills/skills" 2>&1; then
    ok "all skills pass lint"
  else
    bad "some skills fail lint (see above)" "fix the files, then \"upskill sync\""
  fi
  # Duplicate shadowing: same skill name both synced AND in a local skills dir
  # means it loads twice and the copies drift.
  DUPES=0
  for d in "$WORKDIR/plugins/skills/skills"/*/; do
    [ -d "$d" ] || continue
    n="$(basename "$d")"
    for loc in "$HOME/.claude/skills/$n" "$HOME/.codex/skills/$n" "$HOME/.agents/skills/$n"; do
      if [ -f "$loc/SKILL.md" ]; then
        bad "'$n' is synced AND still in $loc (loaded twice, will drift)" "mv \"$loc\" ~/.upskill/trash/  (Upskill owns it now)"
        DUPES=1
      fi
    done
  done
  [ "$DUPES" = 0 ] && ok "no synced skill is shadowed by a local copy"
fi

echo ""
echo "Result: $OK ok, $BAD problem(s)."
[ "$BAD" = 0 ] && echo "You're healthy. Sync away." || echo "Run the fixes above, then /upskill:doctor again."
exit 0
