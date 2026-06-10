# My Upskill skills

This private repo is my personal skill library, managed by
[Upskill](https://github.com/nahiddotai/upskill). Every skill here syncs to all
of my AI agents (Claude Code, Codex, Claude desktop, …).

## Layout

```
.claude-plugin/marketplace.json    ← versioned manifest (bumped on every sync)
plugins/skills/skills/<name>/      ← one folder per skill, each with SKILL.md
```

## How it works

- Edit skills in the local clone at `~/.upskill/workspace`, or just tell your
  agent what to change.
- Say **"upskill sync"** (or `/upskill:sync`) in any client — edits are linted,
  committed, version-bumped, and pushed here; other clients pull on their next
  refresh.
- Full history is kept: nothing synced is ever lost.

Don't edit this repo directly on GitHub while a sync is mid-flight; last push
wins (and history keeps the rest).
