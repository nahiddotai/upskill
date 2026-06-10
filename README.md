<p align="center">
  <img src="logo.svg" width="96" alt="Upskill logo" />
</p>

<h1 align="center">Upskill</h1>

<p align="center"><b>Write a skill once. It's current on every AI agent you use — and shareable with a link.</b></p>

---

Your skills (`SKILL.md` folders) end up scattered and drifting across
`~/.claude/skills`, `~/.codex/skills`, `~/.agents/skills`, and every cloud
client. Anthropic documents that they don't sync. Upskill fixes that with the
rails you already have: a private GitHub repo per user, delivered to every
client as a native plugin, version-bumped on each sync so every client knows
to pull.

- **Free, no accounts of ours, no limits.** Everything runs in your own clients
  on your own plan; GitHub hosts your skills. We never see them.
- **One command a day:** say **"upskill sync"** in any client.
- **Share any skill with a link.** Your public `upskill-shared` repo is your
  skill profile.

## Install (once, ~2 minutes)

Prereqs: `git`, `python3`, [GitHub CLI](https://cli.github.com) (`gh auth login`).

```bash
claude plugin marketplace add nahiddotai/upskill
claude plugin install upskill@upskill
```

Then, in any session:

```
> set up upskill
```

That creates `you/upskill-skills` (private), clones an editable workspace to
`~/.upskill/workspace`, and wires every client found on your machine
(Claude Code, Codex; one-time GUI steps are printed for Claude desktop/Cowork).

## Daily use — one verb

Say **"sync"** (or `/upskill:sync`). That's the product:

- Just built a skill in this conversation? "sync" — the agent knows which one,
  imports it (the original moves to `~/.upskill/trash` so it's never loaded
  twice), pushes, pulls, done.
- In your next client: "sync" — or nothing at all; background refresh
  (throttled ~4h: SessionStart hook, MCP server, pull-on-use — one shared
  throttle) delivers it on its own.
- Have stray skills scattered across `~/.claude/skills` & co? "sync" — the
  agent finds them and asks once which to bring in.

Two more verbs, only when you want them:

| Say / run | What happens |
|---|---|
| `/upskill:share <skill>` | Publish one skill publicly → link + install one-liner; `/upskill:unshare` revokes |
| `/upskill:doctor` | Full health check with the exact fix for anything broken |

## How it works

```
you/upskill-skills (private repo)  ←  "upskill sync" from any client
        │  version bump on every push
        ▼
every client pulls on its next refresh (native plugin update — no daemon)
```

Two plugins, clean namespaces: `upskill:*` is the tooling (this repo, shared by
everyone — one commit here updates all users); `skills:*` is yours (your repo,
private by default).

## Clients

- **Claude Code (CLI)** — full experience: skills, slash commands, background
  refresh via SessionStart hook + MCP server. (Known platform quirk: plugin
  hooks may not fire on the very first session after install — the other
  triggers cover it.)
- **Claude desktop app / Cowork** — install via the UI: Customize → Plugins →
  Personal plugins → Add marketplace → `nahiddotai/upskill` (and your
  `<you>/upskill-skills`). The desktop loads plugin *skills* but not plugin
  hooks/MCP, so Upskill's pull-on-use trigger keeps you current there; new
  skills appear after an app restart.
- **Codex (CLI + app)** — native: the repo ships `.codex-plugin` manifests and
  the `.agents/plugins/marketplace.json` Codex marketplace (plus the
  Claude-format one Codex reads as legacy). `codex plugin marketplace add
  <you>/upskill-skills && codex plugin add skills@upskill-skills`. Note: Codex
  treats plugin-bundled hooks as untrusted until you approve them — sync works
  without them.

## Honest expectations

- Brand-new skills load after `/reload-plugins` (CLI) or an app restart
  (desktop). Edits propagate on each client's refresh cadence — minutes, not
  milliseconds.
- Conflicts: last push wins; full git history keeps everything recoverable.
- Shared skills can bundle scripts. Their generated README discloses every
  script; review before running. Sync itself never executes synced code.
- Windows: bash scripts run under Git Bash with Claude Code — considered beta.

## Uninstall

```
> remove upskill
```

Unwires your clients and deletes `~/.upskill`. Your GitHub repos — your
skills — are kept.

## License

MIT
