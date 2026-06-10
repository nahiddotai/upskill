#!/usr/bin/env bash
# ============================================================================
# Upskill setup — run by the agent when the user says "set up upskill".
#
# Creates YOUR OWN private skills repo (<you>/upskill-skills) from the bundled
# template, clones an editable workspace, writes credentials, and wires the
# AI clients found on this machine. Idempotent: safe to re-run any time
# (it repairs whatever is missing and never overwrites existing skills).
#
# Usage:
#   setup.sh                  # the normal path (needs gh, authenticated)
#   setup.sh --name my-kit    # custom repo name
#   setup.sh --public         # public skills repo (default: private)
#   setup.sh --dry-run        # show what it would do; touch nothing
#   setup.sh --remote <url>   # advanced/testing: use this git remote, skip gh
#
# Env (testing): UPSKILL_SKIP_WIRE=1 skips client wiring.
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../../../template"
SYSTEM_REPO="${UPSKILL_SYSTEM_REPO:-nahiddotai/upskill}"
NAME="upskill-skills"
VISIBILITY="--private"
WORKDIR="${UPSKILL_WORKDIR:-$HOME/.upskill/workspace}"
CREDS="${UPSKILL_CREDENTIALS:-$HOME/.upskill/credentials}"
REMOTE_OVERRIDE=""
DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2;;
    --public) VISIBILITY="--public"; shift;;
    --private) VISIBILITY="--private"; shift;;
    --dry-run) DRY=1; shift;;
    --remote) REMOTE_OVERRIDE="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

say(){ printf '%s\n' "$*"; }
run(){ if [ "$DRY" = 1 ]; then say "  [dry-run] $*"; else eval "$*"; fi; }

# --- preconditions -----------------------------------------------------------
command -v git >/dev/null     || { echo "✗ git not found." >&2; exit 1; }
command -v python3 >/dev/null || { echo "✗ python3 not found." >&2; exit 1; }
[ -f "$TEMPLATE/.claude-plugin/marketplace.json" ] || { echo "✗ template missing at $TEMPLATE" >&2; exit 1; }

if [ -n "$REMOTE_OVERRIDE" ]; then
  LOGIN="local"
  REMOTE="$REMOTE_OVERRIDE"
else
  command -v gh >/dev/null || { echo "✗ GitHub CLI (gh) not found — install it (brew install gh), run 'gh auth login', then retry." >&2; exit 1; }
  gh auth status >/dev/null 2>&1 || { echo "✗ gh is not authenticated — run 'gh auth login' first." >&2; exit 1; }
  LOGIN="$(gh api user -q .login)"
  REMOTE="https://github.com/$LOGIN/$NAME.git"
fi

# detect clients
CLAUDE="$(command -v claude || true)"
CODEX="$(command -v codex || true)"
[ -z "$CODEX" ] && [ -x "/Applications/Codex.app/Contents/Resources/codex" ] && CODEX="/Applications/Codex.app/Contents/Resources/codex"
[ "${UPSKILL_SKIP_WIRE:-0}" = 1 ] && { CLAUDE=""; CODEX=""; }

say "Upskill setup for @$LOGIN"
say "  • skills repo: $REMOTE ($([ "$VISIBILITY" = "--private" ] && echo private || echo public))"
say "  • workspace:   $WORKDIR"
say "  • Claude Code: $([ -n "$CLAUDE" ] && echo found || echo 'not found (skip)')"
say "  • Codex:       $([ -n "$CODEX" ] && echo found || echo 'not found (skip)')"
say ""

# --- 1. create the personal repo from the bundled template -------------------
seed_remote() {
  TMP="$(mktemp -d)"; cp -R "$TEMPLATE/." "$TMP/"
  ( cd "$TMP" \
    && git init -q -b main \
    && git add -A \
    && git -c user.name="$LOGIN" -c user.email="$LOGIN@users.noreply.github.com" commit -q -m "Upskill skills v0.1.0" \
    && git push -q "$REMOTE" HEAD:main )
  rm -rf "$TMP"
}

if [ -n "$REMOTE_OVERRIDE" ]; then
  say "1. seeding $REMOTE from the bundled template (if empty)…"
  if [ "$DRY" = 0 ] && ! git ls-remote --exit-code "$REMOTE" main >/dev/null 2>&1; then seed_remote; fi
elif gh repo view "$LOGIN/$NAME" >/dev/null 2>&1; then
  say "1. repo $LOGIN/$NAME already exists — reusing (your skills are safe)."
else
  say "1. creating $LOGIN/$NAME from the bundled template…"
  if [ "$DRY" = 0 ]; then
    gh repo create "$LOGIN/$NAME" $VISIBILITY -d "My skills, synced everywhere by Upskill" >/dev/null
    seed_remote
  fi
fi

# --- 2. workspace clone (what you edit + push from) --------------------------
say "2. setting up your editable workspace at $WORKDIR…"
if [ "$DRY" = 0 ]; then
  if [ ! -d "$WORKDIR/.git" ]; then rm -rf "$WORKDIR"; git clone -q "$REMOTE" "$WORKDIR"; fi
  [ -z "$REMOTE_OVERRIDE" ] && gh auth setup-git >/dev/null 2>&1 || true
fi

# --- 3. credentials ----------------------------------------------------------
say "3. writing credentials to $CREDS…"
if [ "$DRY" = 0 ]; then
  mkdir -p "$(dirname "$CREDS")"; chmod 700 "$(dirname "$CREDS")" 2>/dev/null || true
  printf 'UPSKILL_REMOTE="%s"\nUPSKILL_WORKDIR="%s"\n' "$REMOTE" "$WORKDIR" > "$CREDS"; chmod 600 "$CREDS"
fi

# --- 4. wire the clients we found (both marketplaces) -------------------------
PERSONAL_SRC="$([ -n "$REMOTE_OVERRIDE" ] && echo "$REMOTE" || echo "$LOGIN/$NAME")"
if [ -n "$CLAUDE" ]; then
  say "4a. wiring Claude Code…"
  run "$CLAUDE plugin marketplace add $SYSTEM_REPO >/dev/null 2>&1 || true"
  run "$CLAUDE plugin install upskill@upskill >/dev/null 2>&1 || true"
  run "$CLAUDE plugin marketplace add $PERSONAL_SRC >/dev/null 2>&1 || true"
  run "$CLAUDE plugin install skills@upskill-skills >/dev/null 2>&1 || true"
fi
if [ -n "$CODEX" ]; then
  say "4b. wiring Codex…"
  run "\"$CODEX\" plugin marketplace add $SYSTEM_REPO >/dev/null 2>&1 || true"
  run "\"$CODEX\" plugin add upskill@upskill >/dev/null 2>&1 || true"
  run "\"$CODEX\" plugin marketplace add $PERSONAL_SRC >/dev/null 2>&1 || true"
  run "\"$CODEX\" plugin add skills@upskill-skills >/dev/null 2>&1 || true"
fi

# --- done --------------------------------------------------------------------
cat <<EOF

✓ Upskill is set up for @$LOGIN.

  Your skills repo:  $REMOTE
  Edit skills in:    $WORKDIR/plugins/skills/skills/   (one folder per skill)
  Sync:              say "upskill sync" in any client
  Check health:      /upskill:doctor

  Other clients, one-time:
    • Claude chat / Cowork (Claude.app): Customize → Plugins → Personal plugins → +
        → Add marketplace → $PERSONAL_SRC → install "skills"
        (and → Add marketplace → $SYSTEM_REPO → install "upskill" for sync commands)
    • Any machine with Claude Code / Codex CLI: install upskill@upskill, then say "set up upskill".
EOF
