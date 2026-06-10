#!/usr/bin/env python3
"""Lint every skill in a skills directory before it is allowed to sync.

Usage: _lint.py <skills_root>

Errors (exit 1, nothing should be pushed):
  - missing SKILL.md
  - missing/unparseable frontmatter
  - bad `name`: empty, >64 chars, or not [a-z0-9-]
  - missing `description` or >1024 chars
Warnings (stderr only, exit stays 0):
  - frontmatter name != folder name
  - total description weight is large (context cost in every session)
"""
import os
import re
import sys

NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")


def frontmatter(text):
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    fm = {}
    for line in text[3:end].splitlines():
        if ":" in line and not line.startswith((" ", "\t", "#")):
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip().strip("\"'")
    return fm


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: _lint.py <skills_root>\n")
        return 2
    root = sys.argv[1]
    if not os.path.isdir(root):
        return 0  # nothing to lint yet

    errors, warnings, desc_total = [], [], 0
    for entry in sorted(os.listdir(root)):
        d = os.path.join(root, entry)
        if not os.path.isdir(d) or entry.startswith("."):
            continue
        md = os.path.join(d, "SKILL.md")
        if not os.path.isfile(md):
            errors.append("%s: missing SKILL.md" % entry)
            continue
        with open(md, encoding="utf-8", errors="replace") as f:
            fm = frontmatter(f.read())
        if fm is None:
            errors.append("%s: SKILL.md has no '---' frontmatter block" % entry)
            continue
        name = fm.get("name", "")
        desc = fm.get("description", "")
        if not name:
            errors.append("%s: frontmatter is missing 'name:'" % entry)
        elif not NAME_RE.match(name):
            errors.append("%s: name '%s' must be 1-64 chars of a-z, 0-9, '-'" % (entry, name))
        elif name != entry:
            warnings.append("%s: frontmatter name '%s' differs from folder name" % (entry, name))
        if not desc:
            errors.append("%s: frontmatter is missing 'description:' (agents can't trigger it)" % entry)
        elif len(desc) > 1024:
            errors.append("%s: description is %d chars (max 1024)" % (entry, len(desc)))
        desc_total += len(desc)

    for w in warnings:
        sys.stderr.write("  ⚠ %s\n" % w)
    if desc_total > 8000:
        sys.stderr.write(
            "  ⚠ your skill descriptions total %d chars — every one loads into every "
            "session on every client; consider trimming or deleting unused skills\n" % desc_total)
    if errors:
        for e in errors:
            sys.stderr.write("  ✗ %s\n" % e)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
