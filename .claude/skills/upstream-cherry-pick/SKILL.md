---
name: upstream-cherry-pick
description: >
  Cherry-pick agentic dev improvements from project repos to upstream templates. WHEN TO PROPOSE: (1) After pushing commits touching high-signal paths, (2) Sprint/milestone review, (3) When agentic tooling is created. Classify commits as: READY (generic), REFINABLE (useful but has hardcoded paths/names—offer to generalize), or SKIP (project-specific). READY examples: .claude/ (agents, skills, hooks, prompts), .cursor/rules/, MCP configs, docs/agentic-processes/, CLAUDE.md, prompt templates. NOT FOR: feature code, business logic, PRDs, project configs, env files. For REFINABLE commits: pause cherry-pick, generalize the code, prepare commit, get approval, then resume  
user-invocable: yes
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git status:*)
  - Bash(git log:*)
  - Bash(git diff:*)
  - Bash(git show:*)
  - Bash(git branch --list:*)
  - Bash(git branch --show-current:*)
  - Bash(git remote -v:*)
  - Bash(git rev-parse:*)
  - Bash(git ls-files:*)
---

## Purpose

Situations where a template repository that gets cloned or
forked to start new projects. Over time, project repos accumulate improvements
that could flow back to the template for other projects to inherit.

This skill guides Claude through safely cherry-picking commits from a project
repo to the upstream template repo.

## Dependencies

- `gh` - GitHub CLI for repo verification and commit preview
- `jq` - JSON processor for parsing API responses


## Scripts

This skill includes executable scripts in `scripts/` that handle deterministic operations:

**preflight-check.sh** - Validates template repo state before cherry-picking
```bash
./scripts/preflight-check.sh <template-repo-path>
# Returns JSON with status: clean, dirty, wrong_branch, or behind
# Exit codes: 0=clean, 1=uncommitted changes, 2=wrong branch, 3=behind remote, 4=invalid path
```

**classify-commits.sh** - Analyzes commits and classifies as generic vs project-specific
```bash
./scripts/classify-commits.sh <remote/branch> [count]
# Returns JSON array with classification for each commit
# Classifications: generic, project_specific, needs_review
```

**conflict-backup.sh** - Detects conflicts, creates backups, outputs structured analysis
```bash
./scripts/conflict-backup.sh [commit-sha] [commit-message]
# Returns JSON with conflict details: files, line numbers, types, backup location
# Exit codes: 0=conflicts backed up, 1=no conflicts, 2=not a repo, 3=backup failed
```

Claude interprets script output and handles edge cases requiring judgment.


## Invocation

When this skill is triggered, confirm operator understands the setup:

```
This skill operates on TWO directories:

1. project repo (where you are now)
2. template repo (where cherry-picks will be applied)

Both must be cloned locally. You'll need push access to the template.

Template repo path [e.g. ~/dev-projects/shared-template]:
```

Store the template path for use in Pre-Flight Checks.

Then prompt for commit scan depth:

```
How many recent commits to scan? [default: 10]:
```

Use this value for the git log command in Step 2.

## Prerequisites

Before starting, verify:

**A: Dependencies installed**

Run the dependency check script:
```bash
./scripts/check-deps.sh
```

The script checks the environment and verifies:
- Operating system is macOS (this skill currently only supports macOS)
- Required dependencies (gh, jq) are installed

If dependencies are missing, the script will:
1. Report which deps are missing (gh, jq)
2. Prompt for approval to install via `brew install`
3. Install if approved, or exit if declined

If the OS is not macOS, the script will exit with an error indicating this skill currently only supports macOS.

**B: Upstream template repo exists locally** (e.g., ~/Code/template)

**C: Project repo was originally cloned/forked from the template**


## Classification Guidance

Read **EXAMPLES.md** for detailed classification patterns with explanations.

Don't rely strictly on commit message prefixes like `[process]`. Use judgment based on:

- File paths (`.claude/`, `.cursor/`, `docs/agentic-processes/`, `tools/prompt-classification-scripts/`)
- Content type (agents, skills, hooks, MCP configs, rules)
- Portability (would this work in another project without modification?)

**High likelihood** - offer to cherry-pick:
- Agent definitions (`.claude/agents/`)
- Skills (`.claude/skills/`)
- Hooks (`.claude/hooks/`)
- MCP server configs (`.mcp.json`, `.cursor/mcp.json`)
- Cursor rules (`.cursor/rules/*.mdc`)
- Process documentation (`docs/agentic-processes/`)
- Bash workflow scripts (`tools/`, `scripts/`)
- CLAUDE.md rule updates
- Reusable automation harnesses
- Prompts

**Skip without asking** - these don't match our goals:
- Feature code in `src/`, `app/`, `pages/`
- PRDs, project-specific docs
- Environment files
- IDE editor preferences (`.vscode/settings.json`, `.cursor/settings.json`)

**Inspect the diff** - these require judgment:
- `package.json`: SKIP if changing project name/version, but READY/REFINABLE if adding agentic packages like `@anthropic-ai/claude-code`, `@modelcontextprotocol/*`, or MCP-related deps
- Mixed commits: If a commit touches both generic and project-specific files, check if they can be separated and but in the refinable bucket

When uncertain, ask the operator.

## Pre-Flight Checks

Run the preflight script to validate template repo state:

```bash
./scripts/preflight-check.sh <template-repo-path>
```

Handle based on exit code:

- **Exit 0 (clean)**: Proceed to Cherry-Pick Procedure
- **Exit 1 (uncommitted changes)**: Stash changes first:
  ```bash
  cd <template-repo>
  git stash push -u -m "pre-cherry-pick-$(date +%Y-%m-%d-%H%M)"
  ```
- **Exit 2 (wrong branch)**: Switch to default branch:
  ```bash
  cd <template-repo>
  git checkout <default-branch>
  ```
- **Exit 3 (behind remote)**: Pull latest:
  ```bash
  cd <template-repo>
  git pull origin <default-branch>
  ```
- **Exit 4 (invalid path)**: Verify template repo path with operator


## Cherry-Pick Procedure

### Step 1: Add temporary remote

```bash
cd <template-repo>

# Verify project repo exists on remote (optional, uses gh CLI)
gh repo view <org>/<project-repo> --json name

# Add project as temporary remote for fetching commits
git remote add tmp-project https://github.com/<org>/<project-repo>.git

# Fetch all branches from the project repo
git fetch tmp-project
```

### Step 2: Identify generic commits

Run the classification script to analyze commits:

```bash
./scripts/classify-commits.sh tmp-project/<branch> <N>
```

The script returns JSON with each commit classified as:
- **generic**: Cherry-pickable (agents, skills, process docs, tools)
- **needs_review**: Claude uses judgment based on file contents
- **project_specific**: Skip (feature code, configs, PRDs)

For commits marked `needs_review`, inspect manually and determine if they are:
- **refinable**: Contains useful tooling but has hardcoded project-specific elements (paths, URLs, project names). Offer to pause cherry-picking, generalize the code, then resume.
- **maybe**: Needs operator judgment on tool/workflow assumptions
- **skip**: Fundamentally project-specific, no modification helps

```bash
git show --stat --oneline <sha>
```

Apply judgment: Does this commit contain reusable process improvements or project-specific code?

### Step 3: Operator review (REQUIRED)

Present identified commits to operator for approval:

```
GENERIC COMMITS TO CHERRY-PICK (oldest first):

| SHA     | Message                        |
|---------|--------------------------------|
| <sha1>  | <message>                      |
|         | -> <file1>                     |
|         | -> <file2>                     |
| <sha2>  | <message>                      |
|         | -> <file1>                     |

REFINABLE (useful but needs generalization):

| SHA     | Message                        | Blocker                    |
|---------|--------------------------------|----------------------------|
| <sha1>  | <message>                      | Hardcoded path: /Users/... |
|         | -> <file1>                     |                            |
|         | Offer: Replace with $PROJECT_ROOT or relative path          |

EXCLUDED (project-specific):

| SHA     | Message                        | Reason        |
|---------|--------------------------------|---------------|
| <sha1>  | <message>                      | <reason>      |
|         | -> <file1>                     |               |
|         | -> <file2>                     |               |
| <sha2>  | <message>                      | <reason>      |
|         | -> <file1>                     |               |

Proceed with cherry-pick? [y/n]
For REFINABLE commits: Want me to pause and generalize them first?
```

Do NOT proceed until operator confirms the commit list is correct.

### Handling REFINABLE commits

If operator wants to refine a commit before cherry-picking:

1. **Pause cherry-pick process** - Note where you stopped
2. **Switch to project repo** - `cd <project-repo>`
3. **Create generalized version** - Take necessary action, ie. replace hardcoded paths/names with variables or placeholders
4. **Prepare commit** - Stage changes and draft commit message
5. **Stop for approval** - Present the diff and proposed commit message to operator
6. **After approval** - Commit the refined version
7. **Resume cherry-pick** - Return to template repo and continue from where you paused

### Step 4: Cherry-pick commits

```bash
# Cherry-pick single commit
git cherry-pick <sha>

# Cherry-pick multiple commits (must be oldest to newest order)
git cherry-pick <sha1> <sha2> <sha3>

# Cherry-pick a range (start is exclusive, end is inclusive)
git cherry-pick <start-sha>^..<end-sha>
```

### Step 5: Handle conflicts (OPERATOR REQUIRED)

If cherry-pick reports conflicts, STOP immediately.

Run the conflict backup script to detect, backup, and analyze conflicts:

```bash
./scripts/conflict-backup.sh <commit-sha> "<commit-message>"
```

The script returns JSON with:
- All conflicted files with line numbers
- Conflict type per file (ADDITION, MODIFICATION, DELETION)
- Backup location (temp/merge-backups/YYYY-MM-DD/)
- Backup success status per file

If exit code is 1 (no conflicts), proceed to Step 6.

For additional context, show the full diff:
```bash
git diff --diff-filter=U
```

Present to operator with analysis:

```
MERGE CONFLICT DETECTED

Commit: <sha> - <message>

Conflicted files:
1. <file1>
   - Lines affected: <line numbers>
   - Conflict type: <type>

2. <file2>
   - Lines affected: <line numbers>
   - Conflict type: <type>

CONFLICT ANALYSIS:

File: <file1>
  HEAD (template):   <brief description of current state>
  INCOMING (project): <brief description of incoming change>

  Recommendation: <one of below>
    - ACCEPT INCOMING: Project version is newer/better
    - KEEP HEAD: Template version should be preserved
    - MERGE BOTH: Both changes are needed, combine manually
    - NEEDS REVIEW: Complex conflict, operator must decide

Backups saved to: temp/merge-backups/<date>/

OPTIONS:

A: Operator resolves conflicts manually, then run:
   git add . && git cherry-pick --continue

B: Abort this cherry-pick and skip this commit:
   git cherry-pick --abort

C: Abort all remaining cherry-picks:
   git cherry-pick --abort
   (do not continue with remaining commits)

Waiting for operator action...
```

Do NOT auto-resolve conflicts. Agent has no permission to modify conflict markers.

Conflict type categories:

- ADDITION: New content added in both branches
- MODIFICATION: Same lines modified differently
- DELETION: One side deleted, other modified
- RENAME: File renamed/moved differently

### Step 6: Push and cleanup

```bash
# Push cherry-picked commits to template repo
git push origin <default-branch>

# Remove temporary remote (no longer needed)
git remote remove tmp-project

# Verify remotes are back to normal
git remote -v

# Restore stashed changes if any were stashed in pre-flight
git stash pop
```

### Step 7: Return to project

```bash
cd <project-repo>

# Check if upstream remote exists
git remote -v | grep upstream
```

If upstream remote exists, disable push to prevent accidental commits to template:

```bash
git remote set-url --push upstream DISABLED
```

If no upstream remote (standalone repo), skip this step.


## Commit Message Convention (Optional Signal)

These prefixes are helpful signals but NOT required for classification:

- `[process]` - suggests generic/shareable content
- `[<project-name>]` - suggests project-specific content

Claude should use file paths and content analysis as primary classification method.
Commit messages are secondary signals that may or may not be present.

## Rigor

**Default enforcement**: required

When `required`:

A: Always stash uncommitted changes in template first
B: Always create backup for conflicts in temp/merge-backups/
C: Always verify remote cleanup after cherry-pick
D: Never force push to template
E: Never auto-resolve merge conflicts - stop for operator

When `exploratory`:
A: Can skip backup creation for simple cherry-picks

## Checklist

- [ ] Template repo has no uncommitted changes (stashed if needed)
- [ ] On default branch in template
- [ ] Pulled latest from origin
- [ ] Temporary remote added
- [ ] Commits classified as generic vs project-specific
- [ ] Operator reviewed and approved commit list
- [ ] Cherry-pick completed without errors
- [ ] Conflicts backed up and resolved (if any)
- [ ] Pushed to template
- [ ] Temporary remote removed
- [ ] Restore stashed changes (git stash pop)
- [ ] Project upstream push still DISABLED
