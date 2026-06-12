---
name: upskill-sync
description: Natural-language router for Upskill. Use when the user says "sync" about skills in any form — "upskill sync", "sync this/my skills", "save/push my skills across agents", "pull/update my skills", "share my <skill>", or "check my upskill status/health".
user-invocable: false
---

```!
bash "${CLAUDE_SKILL_DIR}/scripts/_auto_refresh.sh"
```
<!-- ^ Pull-on-use auto-sync (the desktop path): whenever this sync skill runs,
     it kicks off a throttled (~4h), silent, best-effort background pull so
     installed Upskill skills stay current. This is the ONE trigger that works on
     the Claude desktop app, which loads this plugin's skills but not its hooks
     or MCP server. Throttle-shared with the hook/MCP, so it never double-pulls.
     In agents that don't execute this preamble it renders as an inert code
     block — everything below still works. -->

# Upskill — one verb: sync

There is exactly one thing the user has to know: **"sync" makes their skills
the same everywhere.** It pushes their edits up, pulls everyone else's latest
down, and goes live. Your job is to figure out *which* skills they mean from
context, so they never have to.

The scripts live in the `scripts/` folder **next to this SKILL.md** — in
Claude Code that's `${CLAUDE_SKILL_DIR}/scripts/`; in any other agent, resolve
the path relative to this file. Run them with your shell tool. All run
locally; none call a model.

## When the user says "sync" (any phrasing)

1. **Figure out which skills they mean — don't make them name things:**
   - If skills were **created or edited in this conversation**, those are the
     targets. If they live outside the Upskill workspace (e.g. you just wrote
     one into `~/.claude/skills/`), pass their names as arguments so they get
     imported.
   - If the user named skills ("sync my stripe skill"), use those names.
   - Otherwise run `scripts/discover.sh` (read-only; lists `name<TAB>path` of
     skills in local client dirs not yet in their library). If it finds
     candidates, show the names and ask one short question: *"Also sync these?"*
     — then include the ones they want. If it finds nothing, just sync.
2. **Run it:** `scripts/reconcile.sh [name…]` — handles import + push + pull +
   refresh in one shot. Imported originals are retired to `~/.upskill/trash`
   **only after the synced copy is verified live in every client** (until
   then they stay put — no data loss if a client's refresh fails); mention
   that in your summary, and surface any ⚠ lines the scripts print.
3. **Report in one or two sentences:** what synced, the new version, and that
   brand-new skills load after **`/reload-plugins`** (Claude Code CLI) or an
   **app restart** (desktop). They install at user scope — every project,
   every client.

## Other intents

| Intent | Run |
|---|---|
| just get the latest into this client ("pull") | `scripts/pull.sh` |
| share a skill with a link | `scripts/share.sh <skill-name>` (revoke: `scripts/unshare.sh <skill-name>`) |
| quick status | `scripts/status.sh` |
| anything is broken / health check | `scripts/doctor.sh` — diagnoses and prints exact fixes |
| edit an already-synced skill | edit it in `$UPSKILL_WORKDIR/plugins/skills/skills/<name>/` (read `~/.upskill/credentials` for the path), then sync |

Notes for you, the agent:

- Credentials error from any script → the user hasn't run setup; offer the
  `upskill-setup` skill ("set up upskill").
- Lint failure on push → a skill is malformed; show the lint output, offer to
  fix the SKILL.md, then sync again. Nothing propagates until lint passes.
- Slash forms exist for the user: `/upskill:sync [names…]`, `/upskill:doctor`,
  `/upskill:share`, `/upskill:unshare`.

## How sync stays automatic (background)

Three triggers call the same throttled `scripts/_auto_refresh.sh`, sharing one
~4h stamp (`~/.upskill/.last_refresh`) so they never double-pull: a
SessionStart hook (Claude Code CLI), the auto-sync MCP server (clients that
load plugin MCP servers; also exposes an `upskill_resync` tool), and the
pull-on-use preamble above (every client that executes preambles, incl. the
Claude desktop app). So in the steady state the user syncs in client A and
client B simply has it after its next refresh — no command needed in B.
