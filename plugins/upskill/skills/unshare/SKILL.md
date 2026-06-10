---
name: unshare
description: "Stop sharing a skill publicly and revoke its link. Usage: /upskill:unshare <skill-name>."
argument-hint: "<skill-name>"
disable-model-invocation: true
allowed-tools: Bash(bash *)
---

# Upskill — Unshare a skill

```!
bash "${CLAUDE_SKILL_DIR}/../upskill-sync/scripts/unshare.sh" $ARGUMENTS
```

Confirm to the user whether the skill was unshared, based on the output above.
Mention that copies people already installed keep working — unsharing only
stops new installs.
