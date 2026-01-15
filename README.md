# Claude Code Skills

Reusable skills for AI-assisted workflow automation and process engineering. Built while experimenting with Claude Code, Cursor, and MCP servers.

## Skills

### [upstream-cherry-pick](.claude/skills/upstream-cherry-pick/SKILL.md)
Identifies and extracts reusable workflow patterns from project repos and contributes them upstream to template repos. Analyzes commit content to classify what's portable automation versus project-specific code.

Use case: Continuous process improvement that helps you sync improvements while working on multiple projects


Full docs: [Context](.claude/skills/upstream-cherry-pick/CONTEXT.md)

### [archive-session](.claude/skills/archive-session/SKILL.md)
Archives Claude Code session transcripts and subagent logs with browsable HTML reports. Auto-detects sessions and validates paths for security.

Use case: Keeping detailed process history for complex multi/sub agent execution. Can be inserted into workflows for automatically saving progress before auto-compaction wipes history


## Installation

Copy a skill to your project's `.claude/skills/`:

```bash
cp -r .claude/skills/archive-session ~/.claude/skills/
```

See individual SKILL.md files for usage and dependencies.
