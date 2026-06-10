---
name: share
description: "Publish one of your skills to a public link anyone can install into their own agents. Usage: /upskill:share <skill-name>."
argument-hint: "<skill-name>"
disable-model-invocation: true
allowed-tools: Bash(bash *)
---

# Upskill — Share a skill

```!
bash "${CLAUDE_SKILL_DIR}/../upskill-sync/scripts/share.sh" $ARGUMENTS
```

Show the user the shareable link and the install command from the output
above, and note the generated README discloses any bundled scripts to
recipients. If no skill name was given, tell them to run
`/upskill:share <skill-name>`.
