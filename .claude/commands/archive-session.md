---
description: Archive current session transcript and subagent logs with HTML report
argument-hint: "[session-ref] [--output=path]"
allowed-tools: Bash
---

Archive session transcript and subagent logs. Auto-detects current session, or pass session reference.

Session reference can be: UUID, `last`, `last-1`, `last-2`, etc. (relative to most recent).

```bash
bash .claude/skills/archive-session/scripts/archive.sh $ARGUMENTS
```
