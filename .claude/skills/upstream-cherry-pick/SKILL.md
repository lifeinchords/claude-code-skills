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
- **macOS** (the dependency installer uses Homebrew; Linux may work but is not currently tested/supported)
- A local **project repo** (derived from the template, containing candidate commits)
- A local **template repo** (the upstream destination, with push access)

## Scripts

This skill includes executable scripts in `.claude/skills/upstream-cherry-pick/scripts/` that handle deterministic operations:

**preflight-check.sh** - Validates template repo state before cherry-picking
```bash
./.claude/skills/upstream-cherry-pick/scripts/preflight-check.sh <template-repo-path>
# Returns JSON with status: clean, dirty, wrong_branch, or behind
# Exit codes: 0=clean, 1=uncommitted changes, 2=wrong branch, 3=behind remote, 4=invalid path
```

Note: `preflight-check.sh` is intentionally **non-mutating**. It does **not** run `git fetch` or `git pull`. If remote sync status can't be verified from existing `origin/<default>` refs, it will warn and ask the operator to fetch/pull explicitly.

**list-commits.sh** - Lists commits with metadata (Claude does classification)
```bash
./.claude/skills/upstream-cherry-pick/scripts/list-commits.sh <remote/branch> [count]
# Returns JSON array with: sha, message, files[]
# NO classification - Claude inspects diffs and applies EXAMPLES.md guidance
```

**conflict-backup.sh** - Detects conflicts, creates backups, outputs structured analysis
```bash
./.claude/skills/upstream-cherry-pick/scripts/conflict-backup.sh [commit-sha] [commit-message]
# Returns JSON with conflict details: files, line numbers, types, backup location
# Exit codes: 0=conflicts backed up, 1=no conflicts, 2=not a repo, 3=backup failed
```

**detect-mode.sh** - Suggests cherry-pick vs squash based on commit patterns
```bash
./.claude/skills/upstream-cherry-pick/scripts/detect-mode.sh <remote/branch> [count]
# Returns JSON with: suggested_mode, reason, common_prefix, files[]
# If all commits share a path prefix → suggests squash
# If commits touch scattered paths → suggests cherry-pick
```

Claude interprets script output and handles edge cases requiring judgment.

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

## Classification Guidance

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

Operator confirmation REQUIRED before each of: `git remote add …`, `git fetch …`

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

```
CHERRY PICK RECOMMENDATION (oldest first):

YES (cherry-pick as-is):
| SHA     | Message                                             |
|---------|-----------------------------------------------------|
| <sha1>  | <message>                                           |
|         | -> <file1>                                          |
|         | -> <file2>                                          |
| <sha2>  | <message>                                           |
|         | -> <file1>                                          |

MAYBE (needs changes or judgment):
| SHA     | Message                                | Offer                    |
|---------|----------------------------------------|--------------------------|
| <sha1>  | <message>                              | <what needs fixing>      |
|         | -> <file1>                             | <action to take>         |

NO (project-specific):
| SHA     | Message                        | Reason              |
|---------|--------------------------------|---------------------|
| <sha1>  | <message>                      | <reason>            |
|         | -> <file1>                     |                     |
```

**3b. Present mode choice** (if squash was suggested):

```
MODE OPTIONS:

Suggested: SQUASH (all commits share prefix: .claude/skills/...)

A: Cherry-pick (preserve individual commit history)
B: Squash (combine into single clean commit)

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

### Step 4: Apply commits

**4a. Create feature branch** (if PR delivery chosen):
```bash
git checkout -b feature/<descriptive-name>
```

**4b. Apply commits based on mode:**

**Mode A: Cherry-pick (preserve history)**
```bash
# Cherry-pick multiple commits (oldest to newest)
git cherry-pick <sha1> <sha2> <sha3>

# Or cherry-pick a range
git cherry-pick <first-sha>^..<last-sha>
```

**Mode B: Squash**

Option B1 - Squash locally:
```bash
# Cherry-pick all commits first
git cherry-pick <first-sha>^..<last-sha>

# Then squash into one commit
git reset --soft HEAD~<N>
git commit -m "<Claude drafts descriptive message>"
```

Option B2 - Let GitHub squash:
```bash
# Cherry-pick all commits (history preserved on branch)
git cherry-pick <first-sha>^..<last-sha>

# Push branch, then select "Squash and merge" when merging PR
```

Operator confirmation REQUIRED before: `git cherry-pick …`, `git reset …`, `git commit …`

### Step 5: Handle conflicts (OPERATOR REQUIRED)

If cherry-pick reports conflicts, STOP immediately.

Run the conflict backup script to detect, backup, and analyze conflicts:

```bash
./.claude/skills/upstream-cherry-pick/scripts/conflict-backup.sh <commit-sha> "<commit-message>"
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
See the operator-ready conflict template in `CONFLICT_TEMPLATE.md` (this format is intentionally strict).

Do NOT auto-resolve conflicts. Agent has no permission to modify conflict markers.

Conflict type categories:

- ADDITION: New content added in both branches
- MODIFICATION: Same lines modified differently
- DELETION: One side deleted, other modified
- RENAME: File renamed/moved differently

### Step 6: Push and deliver

**Delivery A: Create PR (recommended)**
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

Operator confirmation REQUIRED before: `git push …`, `gh pr create …`

### Step 7: Cleanup

```bash
# Remove temporary remote
git remote remove tmp-project

# Verify remotes
git remote -v

# Restore stashed changes if any
git stash pop
```

Operator confirmation REQUIRED before: `git remote remove …`, `git stash pop`

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

Operator confirmation REQUIRED before: `git remote set-url --push …`

**Why disable push?** The upstream remote points to your template repo. Disabling push prevents accidentally running `git push upstream` from your project, which would pollute the template with project-specific code. You can still fetch/pull template updates; only pushes are blocked.

If no upstream remote exists (standalone repo), skip this step.


## Error Recovery

### Interrupted Cherry-Pick

If the cherry-pick process is interrupted (Ctrl+C, system crash, connection loss), check the state before resuming:

```bash
cd <template-repo>

# Check if cherry-pick is in progress
git status
```

If you see "You are currently cherry-picking commit..." or "Unmerged paths", you have an in-progress cherry-pick:

**Option A: Resume after fixing conflicts**
```bash
# After manually resolving conflicts:
git add .
git cherry-pick --continue
```

**Option B: Abort and restart**
```bash
# Abort the current cherry-pick
git cherry-pick --abort

# Clean up temporary remote
git remote remove tmp-project 2>/dev/null || true

# Return to clean state
git reset --hard origin/<default-branch>
```

**Option C: Skip problematic commit**
```bash
# Skip this commit and continue with next one
git cherry-pick --skip
```

After recovery, verify the template repo state:
```bash
git status
git log --oneline -5
```

### Script outputs & exit codes (reference)

Not all non-zero exits are “errors” (e.g. `conflict-backup.sh` uses exit code 1 to mean “no conflicts”). For a clean, extractable reference of each script’s JSON output and exit codes, see `SCRIPTS.md`.


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
- [ ] Commits classified as YES/MAYBE/NO
- [ ] Operator reviewed and approved commit list
- [ ] Cherry-pick completed without errors
- [ ] Conflicts backed up and resolved (if any)
- [ ] Pushed to template
- [ ] Temporary remote removed
- [ ] Restore stashed changes (git stash pop)
- [ ] Project upstream push still DISABLED
