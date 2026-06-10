#!/usr/bin/env python3
"""Bump the patch version across EVERY manifest in the repo, in lockstep:

  .claude-plugin/marketplace.json            (Claude Code; Codex legacy-compat)
  .agents/plugins/marketplace.json           (Codex primary location — exact mirror)
  <plugin>/.claude-plugin/plugin.json        (Claude Code plugin manifest)
  <plugin>/.codex-plugin/plugin.json         (Codex plugin manifest)

The .agents mirror is REGENERATED from the canonical .claude-plugin copy on
every bump, so the two can never drift.

Usage: _bump.py <workdir>
Prints the new version of the first plugin to stdout.
"""
import json
import os
import sys


def bump(version):
    parts = (version or "0.0.0").split(".")
    while len(parts) < 3:
        parts.append("0")
    try:
        parts[2] = str(int(parts[2]) + 1)
    except ValueError:
        parts[2] = "1"
    return ".".join(parts[:3])


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def set_version(path, version):
    if not os.path.exists(path):
        return
    with open(path) as f:
        data = json.load(f)
    data["version"] = version
    write_json(path, data)


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: _bump.py <workdir>\n")
        return 2
    workdir = sys.argv[1]
    mkt_path = os.path.join(workdir, ".claude-plugin", "marketplace.json")
    if not os.path.exists(mkt_path):
        sys.stderr.write("no marketplace.json at %s\n" % mkt_path)
        return 1

    with open(mkt_path) as f:
        mkt = json.load(f)

    new_version = None
    for plugin in mkt.get("plugins", []):
        nv = bump(plugin.get("version", "0.0.0"))
        plugin["version"] = nv
        if new_version is None:
            new_version = nv
        source = plugin.get("source", "")
        if isinstance(source, str) and source.startswith("./"):
            plug_dir = os.path.join(workdir, source[2:])
            set_version(os.path.join(plug_dir, ".claude-plugin", "plugin.json"), nv)
            set_version(os.path.join(plug_dir, ".codex-plugin", "plugin.json"), nv)

    write_json(mkt_path, mkt)
    # Regenerate Codex's primary marketplace location as an exact mirror.
    write_json(os.path.join(workdir, ".agents", "plugins", "marketplace.json"), mkt)
    print(new_version or "0.0.1")
    return 0


if __name__ == "__main__":
    sys.exit(main())
