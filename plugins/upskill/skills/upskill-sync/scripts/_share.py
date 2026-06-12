#!/usr/bin/env python3
"""Publish or remove a single skill in the public upskill-shared repo.

Usage: _share.py <shared_dir> <add|remove> <skill_name> <workspace_dir> <login>
Prints the new version (add) or "removed".

Generates, on every change:
  - plugins/<skill>/README.md  — install page WITH a script disclosure section
  - README.md (repo root)      — the profile page listing all shared skills
  - profile.json (repo root)   — display state for the Upskill web app
                                 (order/hidden seeded here; bio/links/accent
                                 and display overrides belong to the web
                                 editor and are NEVER touched by this script)
"""
import json
import os
import shutil
import sys
import time

# The branded web front end. One page per user: <APP_URL>/u/<login>.
# Override with UPSKILL_APP_URL (e.g. when the production domain changes).
APP_URL = os.environ.get("UPSKILL_APP_URL", "https://upskill-app.pages.dev").rstrip("/")


def read_desc(skill_md):
    try:
        with open(skill_md, encoding="utf-8", errors="replace") as f:
            txt = f.read()
    except OSError:
        return ""
    if txt.startswith("---"):
        end = txt.find("\n---", 3)
        fm = txt[3:end] if end != -1 else ""
        for line in fm.splitlines():
            if line.strip().startswith("description:"):
                return line.split(":", 1)[1].strip().strip("\"'")
    return ""


def bump(v):
    p = (v or "0.0.0").split(".")
    while len(p) < 3:
        p.append("0")
    try:
        p[2] = str(int(p[2]) + 1)
    except ValueError:
        p[2] = "1"
    return ".".join(p[:3])


def list_scripts(skill_dir):
    """Every executable-ish file bundled with the skill — disclosed to installers."""
    out = []
    for root, _dirs, files in os.walk(skill_dir):
        for f in sorted(files):
            if f.endswith((".sh", ".py", ".js", ".rb", ".pl")) or os.access(os.path.join(root, f), os.X_OK):
                rel = os.path.relpath(os.path.join(root, f), skill_dir)
                if rel != "SKILL.md":
                    out.append(rel)
    return out


def load_mkt(path, login):
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return {
        "name": "upskill-shared",
        "owner": {"name": login, "url": "https://github.com/%s" % login},
        "metadata": {"description": "Skills %s shares publicly via Upskill." % login, "version": "1.0.0"},
        "plugins": [],
    }


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def write_text(path, lines):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def install_lines(login, name):
    # Codex gets the FULL .git URL — it rejects owner/repo shorthand.
    return [
        "- **Claude Code:** `claude plugin marketplace add %s/upskill-shared && claude plugin install %s@upskill-shared`" % (login, name),
        "- **Codex:** `codex plugin marketplace add https://github.com/%s/upskill-shared.git && codex plugin add %s@upskill-shared`" % (login, name),
        "- **Cowork / Claude chat:** Customize → Plugins → Personal plugins → + → Add marketplace → `%s/upskill-shared` → install **%s**" % (login, name),
    ]


def load_profile(path, login):
    """profile.json with field-level fallbacks — a hand-edited or missing file
    must never break the page or lose the web editor's customizations."""
    prof = {}
    if os.path.exists(path):
        try:
            with open(path) as f:
                prof = json.load(f)
        except (OSError, ValueError):
            prof = {}
    if not isinstance(prof, dict):
        prof = {}
    prof.setdefault("version", 1)
    prof.setdefault("displayName", login)
    prof.setdefault("bio", "")
    prof.setdefault("avatarUrl", None)
    prof.setdefault("accent", "#6366f1")
    prof.setdefault("links", [])
    prof.setdefault("order", [])
    prof.setdefault("hidden", [])
    prof.setdefault("skills", {})
    return prof


def save_profile(path, prof):
    prof["updatedAt"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    write_json(path, prof)


def gen_skill_readme(shared_dir, login, name, desc, ver, scripts):
    out = ["# %s" % name, "", desc or "_(no description)_", "",
           "Shared by [@%s](https://github.com/%s) via [Upskill](https://github.com/nahiddotai/upskill) · v%s" % (login, login, ver),
           "", "**[View this as a page →](%s/u/%s)**" % (APP_URL, login),
           "", "## Install", ""]
    out += install_lines(login, name)
    out += ["", "Installing makes a copy that's fully yours — the author can't change it after you install.", ""]
    if scripts:
        out += ["## ⚠ Bundled scripts", "",
                "This skill ships executable scripts. **Review them before letting your agent run them:**", ""]
        out += ["- [`%s`](skills/%s/%s)" % (s, name, s) for s in scripts]
        out += [""]
    else:
        out += ["_No bundled scripts — markdown only._", ""]
    write_text(os.path.join(shared_dir, "plugins", name, "README.md"), out)


def gen_root_readme(shared_dir, mkt, login):
    out = ["# @%s — skills" % login, "",
           "Skills I share publicly, synced and published with [Upskill](https://github.com/nahiddotai/upskill).",
           "", "**[View this as a page →](%s/u/%s)**" % (APP_URL, login),
           "", "Install any of them into your own AI agents:", ""]
    if not mkt["plugins"]:
        out += ["_(nothing shared yet)_", ""]
    for p in sorted(mkt["plugins"], key=lambda x: x["name"]):
        n = p["name"]
        out += ["## [%s](plugins/%s/README.md)" % (n, n), "", p.get("description", ""), ""]
        out += install_lines(login, n)
        out += [""]
    out += ["---", "", "Want your own synced, shareable skill library? `claude plugin marketplace add "
            "nahiddotai/upskill && claude plugin install upskill@upskill`, then say **\"set up upskill\"**.", ""]
    write_text(os.path.join(shared_dir, "README.md"), out)


def main():
    if len(sys.argv) != 6:
        sys.stderr.write("usage: _share.py <shared_dir> <add|remove> <skill> <workdir> <login>\n")
        return 2
    shared_dir, action, skill, workdir, login = sys.argv[1:6]
    mkt_path = os.path.join(shared_dir, ".claude-plugin", "marketplace.json")
    mkt = load_mkt(mkt_path, login)
    plug_dir = os.path.join(shared_dir, "plugins", skill)
    src = os.path.join(workdir, "plugins", "skills", "skills", skill)

    if action == "add":
        if not os.path.isdir(src):
            sys.stderr.write("skill not found: %s\n" % src)
            return 1
        desc = read_desc(os.path.join(src, "SKILL.md"))
        dest = os.path.join(plug_dir, "skills", skill)
        if os.path.exists(dest):
            shutil.rmtree(dest)
        shutil.copytree(src, dest)
        entry = next((p for p in mkt["plugins"] if p["name"] == skill), None)
        ver = bump(entry["version"]) if entry else "0.1.0"
        if entry:
            entry.update({"source": "./plugins/%s" % skill, "version": ver, "description": desc})
        else:
            mkt["plugins"].append({"name": skill, "source": "./plugins/%s" % skill, "version": ver, "description": desc})
        write_json(os.path.join(plug_dir, ".claude-plugin", "plugin.json"),
                   {"name": skill, "version": ver, "description": desc})
        write_json(mkt_path, mkt)
        gen_skill_readme(shared_dir, login, skill, desc, ver, list_scripts(dest))
        gen_root_readme(shared_dir, mkt, login)
        # Seed the web-app display state: newly shared skills appear at the
        # end of the page, never hidden. Web-editor-owned fields untouched.
        prof_path = os.path.join(shared_dir, "profile.json")
        prof = load_profile(prof_path, login)
        if skill not in prof["order"]:
            prof["order"].append(skill)
        prof["hidden"] = [h for h in prof["hidden"] if h != skill]
        save_profile(prof_path, prof)
        print(ver)
    elif action == "remove":
        mkt["plugins"] = [p for p in mkt["plugins"] if p["name"] != skill]
        if os.path.isdir(plug_dir):
            shutil.rmtree(plug_dir)
        write_json(mkt_path, mkt)
        gen_root_readme(shared_dir, mkt, login)
        prof_path = os.path.join(shared_dir, "profile.json")
        prof = load_profile(prof_path, login)
        prof["order"] = [n for n in prof["order"] if n != skill]
        prof["hidden"] = [h for h in prof["hidden"] if h != skill]
        prof["skills"].pop(skill, None)
        save_profile(prof_path, prof)
        print("removed")
    else:
        sys.stderr.write("action must be add|remove\n")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
