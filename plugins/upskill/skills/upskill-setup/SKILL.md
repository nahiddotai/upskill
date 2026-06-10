---
name: upskill-setup
description: Set up Upskill for this user. Use when the user says "set up upskill", "setup upskill", "install upskill", "get me started with upskill", or "uninstall/remove upskill".
---

# Upskill — Setup

The user wants to set up (or remove) Upskill: their own private GitHub skills
repo that syncs their skills across every AI agent they use.

The scripts live in the `scripts/` folder **next to this SKILL.md** (in Claude
Code that's `${CLAUDE_SKILL_DIR}/scripts/`; in other agents, resolve the path
relative to this file). Run them with your shell tool.

## Set up

1. Check prerequisites yourself first: `git`, `python3`, and `gh` must exist and
   `gh auth status` must succeed. If `gh` is missing or unauthenticated, tell
   the user exactly what to run (`brew install gh`, then `gh auth login`) and
   stop — don't run setup yet.
2. Run `scripts/setup.sh`. It is idempotent and safe to re-run; it never
   overwrites existing skills.
   - `--public` for a public skills repo, `--name <repo>` for a custom name —
     only if the user asks.
3. Relay the summary it prints: where their skills live, that "upskill sync"
   is the only command they need day-to-day, and the one-time steps for GUI
   clients (Claude desktop / Cowork).
4. Suggest the first loop: "create or edit any skill, then say *upskill sync*."

## Uninstall

If the user wants Upskill gone, run `scripts/uninstall.sh --yes` **after they
confirm**. Tell them their GitHub repos are kept, and show the printed
`gh repo delete` commands only if they ask to wipe everything.
