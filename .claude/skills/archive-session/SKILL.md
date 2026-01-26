---
name: archive-session
description: Archive session transcripts + subagent logs to browsable HTML. Supports relative refs (last, last-1, last-2) or UUID. Default output is docs/process/claudeCodeSessions/exported-on-<timestamp>/. User may override with --output=<path>.
user-invocable: true
allowed-tools:
  - Bash(bash .claude/skills/archive-session/scripts/archive.sh:*)
---

# Archive Session

Archives the current Claude Code session transcript and any subagent logs, generating a browsable HTML file.

## When to Use

- Context reaches ~90% capacity (per high-context protocol)
- End of work session for audit trail
- Debugging session or subagent execution

## Arguments

- No arguments: archives to default location `docs/process/claudeCodeSessions/exported-on-<timestamp>/`
- `--output=<path>`: archives to custom location
- Session ref (optional): `last`, `last-1`, `last-2`, or UUID

## What It Does

1. Detects current session (most recently modified transcript)
2. Archives main session transcript (`session.jsonl`)
3. Archives subagent transcripts if present (`subagents/`)
4. Generates HTML file via `claude-code-log` dependency, or uvx
5. Opens file in browser

## Output Location

**Default:** `docs/process/claudeCodeSessions/exported-on-<timestamp>/`

**Override:** Set either `CLAUDE_ARCHIVE_DIR` env var or use `--output=<path>` argument.

**Location override:** Useful in scenarios where you want to archive to a different location to fit other frameworks and processes. 

For example, when using the [Get Shit Done](https://github.com/glittercowboy/get-shit-done) CC framework, a better location might be in `.planning/sessions/`, where that framework generates all of its other plans and records. 

## Default exported folder structure
```
docs/process/claudeCodeSessions/exported-on-2026-01-14_15-51-05/
├── session-info.txt      # Metadata
├── session.jsonl         # Main transcript
├── session.html          # Main session HTML
└── subagents/            # If subagents exist
    ├── agent-a2bad1a.jsonl
    ├── agent-a2bad1a.html    # One HTML per subagent
    ├── agent-b3cde2b.jsonl
    ├── agent-b3cde2b.html
    └── cache/                # Created by claude-code-log (parsed JSON for faster re-renders)
```

## Usage

**Via Claude Code Skill:**

```bash
# Archive current session (auto-detected, to default location)
/archive-session

# Archive specific session by UUID
/archive-session 602fca42-0159-466c-bdb7-00745e1939f1

# Archive using relative references
/archive-session last      # most recent session (same as no arg)
/archive-session last-1    # second most recent
/archive-session last-2    # third most recent

# Archive to custom location
/archive-session --output=./my-archives
/archive-session last-1 --output=./my-archives
/archive-session 602fca42-0159-466c-bdb7-00745e1939f1 --output=./my-archives
```

**Direct Bash Execution:**

```bash
# Archive current session
bash .claude/skills/archive-session/scripts/archive.sh

# Archive with relative reference
bash .claude/skills/archive-session/scripts/archive.sh last
bash .claude/skills/archive-session/scripts/archive.sh last-1

# Archive specific UUID
bash .claude/skills/archive-session/scripts/archive.sh 602fca42-0159-466c-bdb7-00745e1939f1

# Archive to custom location via env var
CLAUDE_ARCHIVE_DIR=~/some/other/path bash .claude/skills/archive-session/scripts/archive.sh

# Archive to custom location via arg
bash .claude/skills/archive-session/scripts/archive.sh --output=./my-archives
bash .claude/skills/archive-session/scripts/archive.sh last-1 --output=./my-archives
```

## TUI for Richer Experience

For interactive session management, `claude-code-log` provides a TUI:

```bash
claude-code-log --tui
# or
uvx claude-code-log@latest --tui
```

Features: session list with timestamps/token counts, keyboard nav (`h` HTML, `m` Markdown, `v` view), cross-project traversal, `c` to resume sessions.

## Dependencies

[claude-code-log](https://github.com/daaain/claude-code-log) generates browsable HTML reports from transcript files. Primarily a TUI with CLI capabilities for batch export.

You can install it as a project dependency or run it on-demand:

**Project dependency** (recommended if using frequently):
```bash
uv add claude-code-log
```
Adds to `pyproject.toml` and installs via [uv package manager](https://docs.astral.sh/uv/).

**On-demand execution** (no install):
```bash
uvx claude-code-log@latest
```
`uvx` is uv's tool runner that fetches and runs packages without permanent installation.

The script checks for `claude-code-log` first, falls back to `uvx`. If neither available, transcripts are still archived but HTML generation is skipped.

Note: You can also use `pip install claude-code-log`, but we default to uv for convenience and speed.

## Script Location

```bash
.claude/skills/archive-session/scripts/archive.sh
```
