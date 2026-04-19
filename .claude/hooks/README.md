## Auto archive session before compaction

Extends the [archive-session](../skills/archive-session/SKILL.md) skill, by enabling Claude Code to *automatically* archive the session right before it compacts context. Great for YOLO mode or long-running orchestration.

### How it works

1. Claude Code internally detects context is full, initiates its compact
2. Claude Code fires `PreCompact` hook, receives session ID via stdin
3. This Hook calls our Skill's `archive.sh` with that session ID
4. Parent and per-subagent logs exported to  `<project-root>/docs/process/claudeCodeSessions/exported-on-<timestamp>/` as `html`, `md`, `json` files 
5. Claude Code compact exxecutes, leaving you with a fresh session context window 

### Install

Copy this hook to your project settings:

```bash
cp -r .claude/hooks /path/to/your/project/.claude/hooks/
```

You can also set it up globally, look up how on the CC docs.

### Configure

Add this block to your project's `.claude/settings.json` file (or merge with any existing `hooks` block). A combined example with both the `permissions` allow rules and this `hooks` block lives at [`.claude/settings.json.example`](../settings.json.example) at the repo root.

`${CLAUDE_PROJECT_DIR}` in the `command` string is an environment variable that Claude Code sets automatically when it invokes a hook. It resolves to the root of the project where `.claude/` lives, so you do not need to hard-code an absolute path. See the [official Claude Code hooks docs](https://docs.claude.com/en/docs/claude-code/hooks) and the [hook-development skill](https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/hook-development/SKILL.md) in the `anthropics/claude-code` repo for the full list of hook env vars.

```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-compact-archive.sh"
          }
        ]
      }
    ]
  }
}
```

### Output path

Default: `<project-root>/docs/process/claudeCodeSessions/exported-on-<timestamp>/`

Override by exporting `CLAUDE_ARCHIVE_DIR` in your shell profile, or edit the hook script to pass `--output=<path>` to `archive.sh`.

## Other hook events

Claude Code supports hooks for many events beyond PreCompact. See the official [Claude Code Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) docs for all possibilities.

## Dependencies

- This repo's `archive-session` Skill
  (`.claude/skills/archive-session/scripts/archive.sh`)

- `jq` — parses JSON hook input from CC stdin. Install:
  - macOS: `brew install jq`
  - Windows: `winget install jqlang.jq`

- `claude-code-log` or `uvx` — generates HTML/Markdown reports.
  Script checks for `claude-code-log` first, falls back to
  `uvx claude-code-log@latest`. If neither available, transcripts
  are archived but report generation is skipped.

- `cygpath` — used by `archive.sh` to normalize Windows paths.
  Ships with Git for Windows (MSYS). No install needed on macOS.