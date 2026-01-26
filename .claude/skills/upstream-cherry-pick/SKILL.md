---
name: upstream-cherry-pick
description: >
  Share reusable agentic patterns from project repos back into an upstream template, safely. WHEN TO PROPOSE: (1) After pushing commits touching high-signal paths, (2) Sprint/milestone review, (3) When agentic tooling is created. Classify commits as: YES (portable), MAYBE (needs changes/judgment—offer to fix), or NO (project-specific). Then prompt the operator for mode (cherry-pick vs squash) and delivery (PR vs direct push) with explicit confirmation gates. For classification, you MUST follow EXAMPLES.md patterns (content-based, not just paths).
version: 2026-01-10
directory: .claude/skills/upstream-cherry-pick
user-invocable: yes
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(./.claude/skills/upstream-cherry-pick/scripts/check-deps.sh:*)
  - Bash(./.claude/skills/upstream-cherry-pick/scripts/preflight-check.sh:*)
  - Bash(./.claude/skills/upstream-cherry-pick/scripts/list-commits.sh:*)
  - Bash(./.claude/skills/upstream-cherry-pick/scripts/detect-mode.sh:*)
  - Bash(./.claude/skills/upstream-cherry-pick/scripts/conflict-backup.sh:*)
  - Bash(git status:*)
  - Bash(git log:*)
  - Bash(git diff:*)
  - Bash(git diff-tree:*)
  - Bash(git show:*)
  - Bash(git branch --list:*)
  - Bash(git branch --show-current:*)
  - Bash(git show-ref:*)
  - Bash(git rev-list:*)
  - Bash(git remote:*)
  - Bash(git remote -v:*)
  - Bash(git rev-parse:*)
  - Bash(git ls-files:*)
---

## Purpose

Situations where a template repository that gets cloned or forked to start new projects. Over time, project repos accumulate improvements that could flow back to the template for other projects to inherit.

This skill guides Claude through safely identifying **reusable agentic patterns** in a project repo and bringing them into an upstream template repo with clear operator decisions (mode + delivery) and strict safety gates (no surprise git state changes).

## Prerequisites (Dependencies + local repos)

This skill requires:
- `gh` - GitHub CLI for repo verification and commit preview
- `jq` - JSON processor for parsing script outputs
- `git` - Version control system for cherry-picking operations
- `bash` - Shell for running scripts (currently supports bash; future: fish, zsh)
- `brew` - macOS package manager for installing dependencies
- Standard Unix utilities (typically preinstalled): `grep`, `sed`, `awk`, `cut`, `tr`, `wc`, `head`, `dirname`, `date`, `cp`, `mkdir`, `file`
- Checksum utility for backups: `shasum` (macOS) or `sha256sum` (Linux)

This skill also assumes:
- **macOS** (Linux may work but is not currently tested/supported)
- A local **project repo** (derived from the template, containing candidate commits)
- A local **template repo** (the upstream destination, with push access)

## Scripts

This skill includes executable scripts in `.claude/skills/upstream-cherry-pick/scripts/` that handle deterministic operations:

**check-deps.sh** - Verifies required tools are installed
```bash
./.claude/skills/upstream-cherry-pick/scripts/check-deps.sh
# Returns JSON with status: ok, missing, declined, or error

# Exit codes: 
# 0=aall deps present or installed successfully
# 1=missing deps and operator declined install (or brew missing)
# 2=install failed
# 3 unsupported OS (currently macOS-only installer)
# On macOS, offers to install missing deps via brew
```

Notes:
- Emits interactive prompts to stderr; final machine-readable status is emitted as JSON on stdout

**preflight-check.sh** - Validates template repo state before cherry-picking without mutating repo state (no fetch/pull).
```bash
./.claude/skills/upstream-cherry-pick/scripts/preflight-check.sh <template-repo-path>
# Returns JSON with status: clean, dirty, wrong_branch, or behind

# Exit codes: 
# 0=clean / OK to proceed (may still include a `warning` field in JSON (for example, missing local ref `origin/<default>`)
# 1=dirty (uncommitted changes present)
# 2=wrong branch
# 3=behind/diverged remote (based on existing local origin/<default> ref only)
# 4=invalid path / not a repo / missing dependency (jq)
```

Note: `preflight-check.sh` is intentionally **non-mutating**. It does **not** run `git fetch` or `git pull`. If remote sync status can't be verified from existing `origin/<default>` refs, it will warn and ask the operator to fetch/pull explicitly.

**list-commits.sh** - Deterministically list commits (sha/message/files) for Claude to classify (NO classification inside the script).
```bash
./.claude/skills/upstream-cherry-pick/scripts/list-commits.sh <remote/branch> [count]
# Returns JSON array with: sha, message, files[]
# NO classification - Claude inspects diffs and applies EXAMPLES.md guidance

# Exit codes:
# 0=success JSON array of objects {sha, message, files[]}
# 1=invalid input/missing dependency/branch not found
```

Notes:
- Enforces an output size cap and may return a partial result with an `"error"` object

**conflict-backup.sh** - Detects conflicts (from cherry-pick OR git apply --3way), creates backups, returns structured JSON. Rejects suspicious paths, skips symlinks, records checksums.
```bash
./.claude/skills/upstream-cherry-pick/scripts/conflict-backup.sh [commit-sha] [commit-message]
# Returns JSON with: conflict_source (merge|patch), files, line numbers, types, backup location

# Exit codes:
# 0=conflicts found, creates temp/merge-backups/YYYY-MM-DD/
# 1=no conflicts detected (not an error)
# 2=not in a git repository
# 3=backup failed or missing dependency (jq)
```

**detect-mode.sh** - Suggests cherry-pick vs squash based on commit patterns
```bash
./.claude/skills/upstream-cherry-pick/scripts/detect-mode.sh <remote/branch> [count]
# Returns JSON with: suggested_mode, reason, common_prefix, files[]
# If all commits share a path prefix → suggests squash
# If commits touch scattered paths → suggests cherry-pick

# Exit codes: 
# 0=success
# 1=invalid input/missing dependency/branch not found
```

Claude interprets script output and handles edge cases requiring judgment.

## Deep details

- **Conflict operator template**: `CONFLICT_TEMPLATE.md`
- **Troubleshooting / recovery**: `TROUBLESHOOTING.md`
- **Operator checklist / rigor**: `CHECKLIST.md`


## Operator confirmation gates (safety-first)

This skill must **not** change repo state without explicit operator confirmation immediately before the command is run.

State-changing commands include (non-exhaustive): `git remote add/remove/set-url`, `git fetch`, `git pull`, `git stash push/pop`, `git cherry-pick`, `git add`, `git commit`, `git push`, and any filesystem writes outside `temp/merge-backups/`.

If the operator says “no” (or is unclear), stop and ask what to do next.


## Invocation

When this skill is triggered, confirm operator understands the setup:

```
This skill operates on TWO directories:

1. project repo (where you are now)
2. template repo (where cherry-picks will be applied)

Both must be cloned locally. You'll need push access to the template.

Template repo path [e.g. ~/dev-projects/shared-agentic-template]:
```

Store the template path for use in Pre-Flight Checks.

Then prompt for commit scan depth:

```
How many recent commits to scan? [default: 10]:
```

Use this value for the git log command in Step 2.

## Classification Guidance Summary

You MUST read **EXAMPLES.md** for the canonical YES/MAYBE/NO classification patterns. Classification is content-based (not just paths), and EXAMPLES.md is the source of truth.

Classify commits into three buckets: **YES**, **MAYBE**, or **NO**.

Don't rely strictly on commit message prefixes like `[process]`. Use judgment based on:
- File paths (`.claude/`, `.cursor/`, `docs/process/`, `tools/`)
- Content type (agents, skills, hooks, MCP configs, rules)
- Portability (would this work in another project without modification?)

**YES** (cherry-pick as-is):
- Agent definitions, skills, hooks (`.claude/`)
- MCP configs (`.mcp.json`, `.cursor/mcp.json`)
- Cursor rules (`.cursor/rules/*.mdc`)
- Agentic process configs (`agent-vm-setup/compose.yml`)
- Agentic process docs (`docs/process/agentic-setup.md`)
- Agentic workflow scripts (`scripts/mcp-setup.sh`, `tools/analyze-transcripts.sh`, `.claude/hooks/`)
- CLAUDE.md rule updates
- Prompts for agentic workflows

**NO** (project-specific - skip):
- Feature code (`src/`, `app/`, `pages/`)
- PRDs, project-specific docs
- Environment files
- IDE editor prefs (`.vscode/settings.json` with font/theme changes only)

**MAYBE** (needs changes or judgment):
- `.cursor/settings.json` → Inspect: AI model config = YES, editor prefs = NO
- Scripts with hardcoded paths → Offer to parameterize
- Hooks that assume specific tools (biome, eslint) → Ask if template uses them
- `package.json` changes → Inspect diff: agentic packages = YES, project name = NO
- Mixed commits → Can they be split or generalized?

When uncertain, classify as MAYBE and present with an "Offer:" explaining what needs fixing or deciding.

## Pre-Flight Checks

Run the preflight script to validate template repo state:

```bash
./.claude/skills/upstream-cherry-pick/scripts/preflight-check.sh <template-repo-path>
```

If output indicates any non-clean state, stop and ask operator how to proceed.

For exit codes and operator actions, see `TROUBLESHOOTING.md`.


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

### Step 2: List, classify, and detect mode

**2a. List commits:**
```bash
./.claude/skills/upstream-cherry-pick/scripts/list-commits.sh tmp-project/<branch> <N>
```

**2b. Detect suggested mode:**
```bash
./.claude/skills/upstream-cherry-pick/scripts/detect-mode.sh tmp-project/<branch> <N>
```

If `suggested_mode` is `squash` (all commits share a path prefix), present mode choice to operator.

**2c. Classify each commit:**

For each commit, inspect the diff:
```bash
git show <sha>
```

Apply **EXAMPLES.md** guidance to determine classification:
- **YES**: Cherry-pickable as-is (agents, skills, hooks, MCP configs, process docs)
- **MAYBE**: Needs changes or judgment (hardcoded paths, tool assumptions, mixed content)
- **NO**: Project-specific (feature code, PRDs, env files)

For MAYBE commits, determine subtype:
- **refinable**: Has hardcoded paths/URLs/project names. Offer to parameterize.
- **needs judgment**: Tool or workflow assumptions. Ask operator.
- **skip**: Fundamentally project-specific, no modification helps.

### Step 3: Operator review (REQUIRED)

**3a. Present classification using EXACTLY this format:**

Present all commits in one chronological table (oldest first). The Class column indicates YES/MAYBE/NO, and the Notes column explains the offer (for MAYBE) or reason (for NO).

```
CHERRY PICK RECOMMENDATION (<N> commits, oldest first):

| #  | Class | SHA     | Message                          | Notes                    |
|----|-------|---------|----------------------------------|--------------------------|
| 1  | YES   | <sha1>  | <message>                        |                          |
|    |       |         | -> <file1>                       |                          |
|    |       |         | -> <file2>                       |                          |
| 2  | MAYBE | <sha2>  | <message>                        | <offer: what to fix>     |
|    |       |         | -> <file1>                       |                          |
| 3  | NO    | <sha3>  | <message>                        | <reason: why skipped>    |
|    |       |         | -> <file1>                       |                          |
| 4  | YES   | <sha4>  | <message>                        |                          |
|    |       |         | -> <file1>                       |                          |
```

**3b. Present mode choice** (if squash was suggested):

If YES commits are non-sequential, warn operator about potential multiple conflict resolutions:

```
MODE OPTIONS:

Suggested: SQUASH (all commits share prefix: .claude/skills/...)

A: Cherry-pick (preserve individual commit history)
B: Squash (combine into single clean commit)

Note: Selected commits are non-sequential (#1, #4, #7). Both modes apply
commits individually, so conflicts may need resolution per commit.
See CONTEXT.md "Squash limitations" for details.

Which mode?
```

**3c. If squash selected, present squash options:**

```
SQUASH OPTIONS:

A: Squash locally (reset + commit before push)
B: Let GitHub squash on merge (push commits, select "Squash and merge" in PR)

Which squash style?
```

**3d. Present delivery choice:**

```
DELIVERY OPTIONS:

A: Create PR (recommended - allows review before merge)
B: Direct to branch (push directly to <default-branch>)

Which delivery?
```

Do NOT proceed until operator confirms all choices.

### Handling MAYBE commits

If operator asks to fix a MAYBE commit before cherry-picking:

1. **Pause the cherry-pick workflow**
2. **Switch to project repo**: `cd <project-repo>`
3. **Make the fix**: Parameterize paths, replace project names, etc.
4. **Present diff and commit message** for operator approval
5. **After approval**: Commit the fixed version
6. **Resume cherry-picking**: Return to template repo and continue

### Step 4: Apply commits (compact)

- **If Delivery = PR**:
  - Create a branch: `git checkout -b feature/<descriptive-name>`
- **If Mode = Cherry-pick**:
  - Apply commits (oldest → newest) with `-x` flag to record source: `git cherry-pick -x <sha1> <sha2> ...`
  - The `-x` flag appends `(cherry picked from commit <sha>)` to each commit message
  - Or apply a range: `git cherry-pick -x <first-sha>^..<last-sha>`
    - If `<first-sha>` is the repository root commit (no parent), `<first-sha>^` fails. Use explicit SHAs instead.
- **If Mode = Squash (locally)**:
  - Cherry-pick all commits: `git cherry-pick <sha1> <sha2> <sha3> ...`
  - **Note:** Non-sequential commits may require conflict resolution per commit (see CONTEXT.md "Squash limitations")
  - Squash into single commit: `git reset --soft HEAD~<N>` where N = number of commits applied
  - Stage and commit with source reference: `git add . && git commit -m "<Claude drafts descriptive message>

cherry picked from: <sha1>, <sha2>, <sha3>"`
- **If Mode = Squash (GitHub)**:
  - Same cherry-pick + reset approach as local squash, but commit to feature branch
  - Include source reference in commit message (list all SHAs)
  - Push feature branch, create PR

### Step 5: Handle conflicts (OPERATOR REQUIRED)

If cherry-pick reports conflicts, STOP immediately.

Run the conflict backup script to detect, backup, and analyze conflicts:

```bash
./.claude/skills/upstream-cherry-pick/scripts/conflict-backup.sh <commit-sha> "<commit-message>"
```

The script returns JSON with:
- `conflict_source`: "merge" (cherry-pick) or "patch" (git apply --3way)
- All conflicted files with line numbers
- Conflict type per file (ADDITION, MODIFICATION, DELETION)
- Backup location (temp/merge-backups/YYYY-MM-DD/)

If exit code is 1 (no conflicts), proceed to Step 6.

For additional context, show the full diff:
```bash
git diff --diff-filter=U
```

Present to operator with analysis:
See the operator-ready conflict template in `CONFLICT_TEMPLATE.md` (this format is intentionally strict).

Do NOT auto-resolve conflicts. Agent has no permission to modify conflict markers.

Conflict type categories:

- ADDITION: New content added in both branches
- MODIFICATION: Same lines modified differently
- DELETION: One side deleted, other modified
- RENAME: File renamed/moved differently

### Step 6: Push and deliver

**Delivery A: Create PR**
```bash
# Push feature branch
git push origin feature/<branch-name>

# Create PR (Claude drafts title and body)
gh pr create --title "<title>" --body "<description>"
```

If operator chose "Let GitHub squash", remind them to select **"Squash and merge"** when merging the PR.

**Delivery B: Direct to branch**
```bash
# Push directly to default branch
git push origin <default-branch>
```

### Step 7: Cleanup

```bash
# Remove temporary remote
git remote remove tmp-project

# Verify remotes
git remote -v

# Restore stashed changes if any
git stash pop
```

### Step 8: Return to project and secure upstream

```bash
cd <project-repo>

# Check if upstream remote exists
git remote -v | grep upstream
```

If upstream remote exists, disable push to prevent accidentally pushing project code to template:

```bash
# This sets the push URL to "DISABLED" while keeping fetch URL intact
# Prevents: git push upstream (which would send project code to template)
# Allows: git pull upstream main (to get future template updates)
git remote set-url --push upstream DISABLED
```

**Why disable push?** The upstream remote points to your template repo. Disabling push prevents accidentally running `git push upstream` from your project, which would pollute the template with project-specific code. You can still fetch/pull template updates; only pushes are blocked.

If no upstream remote exists (standalone repo), skip this step.

