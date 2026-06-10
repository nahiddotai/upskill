---
name: doctor
description: Diagnose the Upskill setup end to end (credentials, repo, drift, duplicate skills, lint) and print exact fixes. Use for /upskill:doctor or when any Upskill command misbehaves.
allowed-tools: Bash(bash *)
---

# Upskill — Doctor

```!
bash "${CLAUDE_SKILL_DIR}/../upskill-sync/scripts/doctor.sh"
```

Walk the user through the report above: lead with whether they're healthy, and
for each ✗ explain the printed fix in one sentence. Offer to run the fixes
that are safe (sync, re-setup); never delete anything without asking.
