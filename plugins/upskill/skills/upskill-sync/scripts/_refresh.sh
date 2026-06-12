#!/usr/bin/env bash
# upskill: refresh the INSTALLED plugins in each local client so newly synced
# skills become live, VERIFY they actually landed, and only then retire any
# imported originals to ~/.upskill/trash. Covers BOTH marketplaces:
#   • upskill         (the shared tooling plugin — platform updates)
#   • upskill-skills  (your personal skills plugin)
# Best-effort across clients — one failing must not abort the others — but
# failures are REPORTED, never silently swallowed (that's how a client can
# drift for weeks without anyone noticing).
set -uo pipefail

CREDS="${UPSKILL_CREDENTIALS:-$HOME/.upskill/credentials}"
# shellcheck source=/dev/null
[ -f "$CREDS" ] && . "$CREDS"
WORKDIR="${UPSKILL_WORKDIR:-}"
REMOTE="${UPSKILL_REMOTE:-}"
PENDING="$HOME/.upskill/.pending_imports"
WARN=0

warn(){ echo "  ⚠ $1"; WARN=1; }

try(){ # try <client-label> <cmd…> — run, report the failure instead of hiding it
  local label="$1"; shift
  local out
  if ! out="$("$@" 2>&1)"; then warn "$label: ${out##*$'\n'}"; return 1; fi
  return 0
}

# Version the refresh should bring every client up to (the workspace just
# pushed it). Used to verify the refresh actually worked.
VER=""
if [ -n "$WORKDIR" ] && [ -f "$WORKDIR/plugins/skills/.claude-plugin/plugin.json" ]; then
  VER="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("version",""))' \
        "$WORKDIR/plugins/skills/.claude-plugin/plugin.json" 2>/dev/null || true)"
fi

did=0

# --- Claude Code (CLI / desktop) ----------------------------------------------
if command -v claude >/dev/null 2>&1; then
  # Self-heal: re-register a missing personal marketplace (FULL git URL — the
  # owner/repo shorthand is not portable across clients).
  if [ ! -d "$HOME/.claude/plugins/marketplaces/upskill-skills" ] && [ -n "$REMOTE" ]; then
    try "Claude Code" claude plugin marketplace add "$REMOTE"
  fi
  try "Claude Code" claude plugin marketplace update upskill
  try "Claude Code" claude plugin update upskill@upskill
  try "Claude Code" claude plugin marketplace update upskill-skills
  try "Claude Code" claude plugin update skills@upskill-skills
  echo "  • Claude Code: plugins refreshed"
  did=1
fi

# --- Codex (CLI on PATH, else the Codex.app bundled binary) --------------------
CODEX="$(command -v codex || true)"
[ -z "$CODEX" ] && [ -x "/Applications/Codex.app/Contents/Resources/codex" ] && CODEX="/Applications/Codex.app/Contents/Resources/codex"
if [ -n "$CODEX" ]; then
  if ! "$CODEX" plugin marketplace list 2>/dev/null | grep -qE '^upskill-skills[[:space:]]' && [ -n "$REMOTE" ]; then
    try "Codex" "$CODEX" plugin marketplace add "$REMOTE"
  fi
  try "Codex" "$CODEX" plugin marketplace upgrade upskill
  try "Codex" "$CODEX" plugin add upskill@upskill
  try "Codex" "$CODEX" plugin marketplace upgrade upskill-skills
  try "Codex" "$CODEX" plugin add skills@upskill-skills
  echo "  • Codex: plugins refreshed"
  did=1
fi

# --- verify, then (and only then) retire imported originals -------------------
# A pending import is a skill whose original still sits in a client dir
# (e.g. ~/.claude/skills/<name>). It is moved to ~/.upskill/trash ONLY once
# the synced copy is confirmed live in every client cache on this machine —
# a failed refresh must never cost the user their only copy.
verified_in(){ # verified_in <cache-root> <skill>
  [ -n "$VER" ] || return 1
  [ -f "$1/upskill-skills/skills/$VER/skills/$2/SKILL.md" ]
}
live_everywhere(){ # live_everywhere <skill> — checks every client cache present
  local s="$1" checked=0
  if [ -d "$HOME/.claude/plugins/cache" ]; then
    checked=1; verified_in "$HOME/.claude/plugins/cache" "$s" || return 1
  fi
  if [ -d "$HOME/.codex/plugins/cache" ]; then
    checked=1; verified_in "$HOME/.codex/plugins/cache" "$s" || return 1
  fi
  [ "$checked" = 1 ]
}

if [ -s "$PENDING" ]; then
  REMAIN="$(mktemp)"
  while IFS=$'\t' read -r name src; do
    [ -n "$name" ] || continue
    if [ ! -d "$src" ]; then continue; fi   # already gone — nothing to retire
    if live_everywhere "$name"; then
      TRASH="$HOME/.upskill/trash/$(date -u +%Y%m%dT%H%M%SZ)-$name"
      mkdir -p "$(dirname "$TRASH")"
      mv "$src" "$TRASH"
      echo "  • '$name' verified live in your clients — original retired to $TRASH"
    else
      printf '%s\t%s\n' "$name" "$src" >> "$REMAIN"
      warn "'$name' is not yet live in every client — keeping the original at $src (retried on next sync; run /upskill:doctor if this persists)"
    fi
  done < "$PENDING"
  if [ -s "$REMAIN" ]; then mv "$REMAIN" "$PENDING"; else rm -f "$REMAIN" "$PENDING"; fi
fi

if [ "$did" = 1 ]; then
  echo "↻ Run /reload-plugins (Claude Code CLI) or restart the app to load updated skills (they install globally)."
else
  echo "  (no client CLI found — desktop apps pull on their own refresh, or update via the app's Plugins screen)"
fi
[ "$WARN" = 1 ] && echo "  Some steps need attention (⚠ above) — /upskill:doctor prints exact fixes."
exit 0
