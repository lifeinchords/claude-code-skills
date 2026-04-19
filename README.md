# Claude Code Tools

Reusable skills for AI-assisted workflow automation and process engineering. Built while experimenting with Claude Code, Cursor, and MCP servers.


## [upstream-cherry-pick](.claude/skills/upstream-cherry-pick/SKILL.md) Skill

> **Note:** Only tested on macOS.

Say you work on many projects, all started from a project template. You have your AI rules, skills, agents, and docs tuned to your tools, stack and IDE's. As you iterate, you find yourself improving workflows in the child projects.

This skill helps you extract those commits back to your template repo. It:

- intelligently analyzes recent commits by content
- classifies them as YES/NO/MAYBE for reusability
- gives you a detailed analysis, with the key files changed in each commit you don't need to switch to git history view for investigation
- interactively guides you through the cherry-picking process, safely taking care of the complex git steps. It prioritizes **safety** so changes in both the child (project) and parent (template) are respected/saved


### Installation

```bash
cp -r .claude/skills/upstream-cherry-pick /path/to/your/project/.claude/skills/
```

### Usage

#### Permissions: Allowing autorun

Each skill declares its required tools in YAML frontmatter (`SKILL.md`). That tells Claude Code which tools the skill *can request*. But Claude Code still checks your permission settings before executing them (and that's a good thing).

Without a matching `allow` entry, you get prompted every time a script runs.

**Why `bash` prefix matters:** Claude Code permission matching is literal prefix matching against the command string the agent generates. When the agent runs `bash .claude/skills/.../script.sh`, the allow rule must start with `Bash(bash .claude/skills/...` to match. If the rule used `Bash(.claude/skills/...` (no `bash`), or the agent used an absolute path like `bash /Users/you/project/.claude/skills/...`, the pattern won't match and you get prompted. The `bash` prefix, the relative path, and the `:*` wildcard suffix must all align between the SKILL.md `allowed-tools`, the `settings.json` allow rules, and the actual command the agent generates.

Add the entries below to `permissions.allow` in either:

- **Project-level** (recommended): `.claude/settings.json` in your project root. Checked into git, shared with collaborators.

- **Global-level**: `~/.claude/settings.json`. Applies to all projects. Useful if you install these skills everywhere.


```json
{
  "permissions": {
    "allow": [
      "Bash(bash .claude/skills/upstream-cherry-pick/scripts/check-deps.sh:*)",
      "Bash(bash .claude/skills/upstream-cherry-pick/scripts/conflict-backup.sh:*)",
      "Bash(bash .claude/skills/upstream-cherry-pick/scripts/detect-mode.sh:*)",
      "Bash(bash .claude/skills/upstream-cherry-pick/scripts/list-commits.sh:*)",
      "Bash(bash .claude/skills/upstream-cherry-pick/scripts/preflight-check.sh:*)",
      "Skill(upstream-cherry-pick)"
    ]
  }
}
```

<br>

###### Verifying

Restart Claude Code and invoke the skill with `/upstream-cherry-pick` or by asking it to run it in your chat session.

Scripts should run without prompts. If you still get prompted, check that:

- Path patterns have no typos -- they must exactly match the command Claude generates

- Scripts are invoked with **relative paths** (e.g. `bash .claude/skills/...`), not absolute paths. Permission matching is literal, so `bash /Users/you/...` will not match a `bash .claude/...` allow rule.

Run `/permissions` in a session to inspect active rules.

#### Full docs

- [how it works](.claude/skills/upstream-cherry-pick/references/CONTEXT.md)
- [examples](.claude/skills/upstream-cherry-pick/EXAMPLES.md) 

---


## [archive-session](.claude/skills/archive-session/SKILL.md): Skill + Slash Command + Optional Hook

**Note:** Works on both **macOS** and **Windows** (Git Bash / MSYS2).

This extension ships three ways to trigger an archive:

- **Skill** (`/archive-session` via the Claude Code skill system). Invoke mid-chat when you want to capture the current session.
- **Slash command** (`.claude/commands/archive-session.md`). Same `/archive-session` trigger, works on installs where the skill system does not auto-register user-invocable skills as commands.
- **Optional PreCompact hook** (`.claude/hooks/pre-compact-archive.sh`). Fires automatically right before Claude Code compacts context, so nothing is lost. See the [bonus combo section](#super-bonus-combo-precompact-hook) below.

Claude Code stores session transcripts in its hidden directory, but that's not meant to persist long-term. This skill saves your process history so you can inspect it later:

- **Track chain of thought**: See exactly how Claude reasoned through problems and arrived at solutions

- **Inspect subagent behavior**: When you spin up agents, see what context they received from the parent session, every step they took, and what they returned.

- **Use valuable context later**: Keep easily searchable Markdown for your next debugging and planning session

Export formats:

- **Markdown**: Clean text for feeding back into Claude, and for context-friendly agentic and manual search in your IDE
- **HTML**: Rich browser view with all tool calls, thinking, and command results with User/Assistant/Agent search filtering
- **JSON**: Full session exactly as Claude Code captured it

### Installation

**macOS / Linux:**
```bash
cp -r .claude/skills/archive-session /path/to/your/project/.claude/skills/
```

**Windows (Git Bash / PowerShell):**
```bash
cp -r .claude/skills/archive-session D:/path/to/your/project/.claude/skills/
```

**Dependencies:** The amazing [claude-code-log](https://github.com/daaain/claude-code-log) does the heavy lifting. The Skill falls back to `uvx claude-code-log@latest` if Python not installed.


### Usage

Invoke with `/archive-session` or ask Claude to run it in your chat. Output path is configurable: archive to a project folder, an Obsidian vault, or any knowledge management system or absolute/network path.

**macOS example output:**
```
docs/process/claudeCodeSessions/exported-on-2026-02-09_10-30-00/
├── session.html
├── session.md
├── session.jsonl
└── session-info.txt
```

**Windows example output:**
```
D:\code\my-project\docs\process\claudeCodeSessions\exported-on-2026-02-09_10-30-00\
├── session.html
├── session.md
├── session.jsonl
└── session-info.txt
```

### Permissions: Allowing autorun

- **Project-level** (recommended): `.claude/settings.json` in your project root. Checked into git, shared with collaborators.

- **Global-level**: `~/.claude/settings.json`. Applies to all projects. Useful if you install these skills everywhere.


```json
{
  "permissions": {
    "allow": [
      "Bash(bash .claude/skills/archive-session/scripts/archive.sh:*)",
      "Skill(archive-session)"
    ]
  },
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

The `hooks` block is only required if you want the [PreCompact auto-archive](#super-bonus-combo-precompact-hook). If you just want the `/archive-session` slash command, keep only the `permissions` block.

A ready-to-copy version of both blocks lives at [`.claude/settings.json.example`](.claude/settings.json.example). Copy what you need into your own `.claude/settings.json` (or merge with any existing allow rules and hooks already there).

<br>

###### Verifying

Restart Claude Code and invoke the skill with `/archive-session` or by asking it to run it in your chat session.

Scripts should run without prompts. If you still get prompted, check that:

- Path patterns have no typos -- they must exactly match the command Claude generates

- Scripts are invoked with **relative paths** (e.g. `bash .claude/skills/...`), not absolute paths. Permission matching is literal, so `bash /Users/you/...` will not match a `bash .claude/...` allow rule.

Run `/permissions` in a session to inspect active rules.

### Full docs

[SKILL.md](.claude/skills/archive-session/SKILL.md)

### Super bonus combo: [PreCompact hook](.claude/hooks/README.md)

If you run Claude Code with auto-compact, this Hook will use the Skill for auto-archiving on context compaction.

**How it works:**

1. Claude Code detects context is full, initiates compact
2. `PreCompact` hook fires, receives session ID via stdin
3. Hook calls `archive.sh` with that session ID, the same scripts the Skill uses
4. Full transcript + subagent logs archived to `docs/process/claudeCodeSessions/exported-on-<timestamp>/`
5. Claude Code compact executes, leaving you with a fresh session context window

Read the [hook setup docs](.claude/hooks/README.md).

---


## [dep-recon](.claude/skills/dep-recon/SKILL.md) Skill

> **Note:** Works on both **macOS** and **Windows** (Git Bash / MSYS2). Requires `gh` CLI authenticated.

When you ask Claude "does flag X exist in tool Y?" or "what version added feature Z?", the agent usually reaches for WebFetch or Context7. Both silently truncate. WebFetch converts HTML to Markdown via Turndown, then caps the result at 100KB.

Context7 chunks documentation and returns partial results that look complete.

Neither tool tells the agent "your answer was cut off" and neither guarantees the symbol you searched for was in the chunk that came back.

`dep-recon` flips the default. Instead of starting with a summary layer, it probes the dependency's actual source on GitHub first:

- **Ground truth before speculation**: local clone Grep (if available) → `gh search code` in the official repo → only then falls back to Context7 / WebFetch with explicit corroboration required
- **Treats empty results as signal, not conclusion**: runs unqualified, then qualified (`path:*.md`, `language:<lang>`), then term variants (snake_case, camelCase, kebab-case) before concluding a symbol is absent
- **Answers the right question shapes**: "does X exist", "what version added X", "was X removed", "how does Y handle X", "is there a way to X in Y"
- **Surfaces the source**: reports which file, which line, which release, which issue, so you can verify yourself

### Installation

**macOS / Linux:**
```bash
cp -r .claude/skills/dep-recon /path/to/your/project/.claude/skills/
```

**Windows (Git Bash / PowerShell):**
```bash
cp -r .claude/skills/dep-recon D:/path/to/your/project/.claude/skills/
```

**Dependencies:** GitHub CLI (`gh`) authenticated via `gh auth login`. No other install step.

### Usage

Invoke with `/dep-recon <term> <owner/repo>` or ask Claude to run it when you're about to make an existence claim about a library. Example: `/dep-recon skip_output evilmartians/lefthook`.

### Permissions: Allowing autorun

- **Project-level** (recommended): `.claude/settings.json` in your project root. Checked into git, shared with collaborators.

- **Global-level**: `~/.claude/settings.json`. Applies to all projects. Useful if you install these skills everywhere.

```json
{
  "permissions": {
    "allow": [
      "Bash(gh search code:*)",
      "Bash(gh search issues:*)",
      "Bash(gh search prs:*)",
      "Bash(gh release list:*)",
      "Bash(gh release view:*)",
      "Bash(gh api:*)",
      "Skill(dep-recon)"
    ]
  }
}
```

<br>

###### Verifying

Restart Claude Code and invoke with `/dep-recon <term> <owner/repo>`. Scripts should run without prompts. If you still get prompted, check that:

- Path patterns have no typos -- they must exactly match the command Claude generates

- `gh auth status` reports authenticated. Unauthenticated `gh search` will prompt or fail silently.

Run `/permissions` in a session to inspect active rules.

### Full docs

[SKILL.md](.claude/skills/dep-recon/SKILL.md) covers the three-phase flow (local Grep → `gh search` → fallback), the truncation-as-signal rule, and the confidence gradient that decides when Context7 + WebFetch are trustworthy as corroboration vs primary sources.

### References

- Claude's internals truncate results at 100KB, and the tool-result budget downstream is 50KB with a 2KB preview if exceeded (see [Mikhail Shilkov, "Inside Claude Code's Web Tools"](https://mikhail.io/2025/10/claude-code-web-tools/)).
 

---


