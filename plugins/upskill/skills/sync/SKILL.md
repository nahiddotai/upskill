---
name: sync
description: "Sync your skills everywhere: push your edits up, pull the latest down, make it live. Name skills to import freshly-created ones, e.g. /upskill:sync my-new-skill other-skill."
argument-hint: "[skill-names…]"
disable-model-invocation: true
allowed-tools: Bash(bash *)
---

# Upskill — Sync

```!
bash "${CLAUDE_SKILL_DIR}/../upskill-sync/scripts/reconcile.sh" $ARGUMENTS
```

Report the result above in a sentence or two: what synced, the new version (or
"nothing to sync"), any lint failures. If skills were imported, mention the
originals were moved to `~/.upskill/trash` so they aren't loaded twice. If a
reload note was printed, remind the user brand-new skills load after
`/reload-plugins` (CLI) or an app restart (desktop).

If no arguments were given and the output shows nothing was imported, you may
also run `${CLAUDE_SKILL_DIR}/../upskill-sync/scripts/discover.sh` — if it
lists unsynced local skills, offer to include them next time:
`/upskill:sync <name>`.
