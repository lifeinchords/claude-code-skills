---
name: upstream-cherry-pick
description: >
  Cherry-pick agentic patterns from project repos to upstream templates. WHEN TO PROPOSE: (1) After pushing commits touching high-signal paths, (2) Sprint/milestone review, (3) When agentic tooling is created. Classify commits as: YES (portable), MAYBE (needs changes/judgment—offer to fix), or NO (project-specific). YES examples: .claude/ (agents, skills, hooks, prompts), .cursor/rules/, MCP configs, docs/process/, CLAUDE.md, workflow scripts. NOT FOR: feature code, business logic, PRDs, project configs, env files. For MAYBE commits: present with "Offer:" describing what needs fixing
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

This skill requires:
- `gh` - GitHub CLI for repo verification and commit preview
- `jq` - JSON processor for parsing script outputs
- `git` - Version control system for cherry-picking operations
- `bash` - Shell for running scripts (currently supports bash; future: fish, zsh)
- `brew` - macOS package manager for installing dependencies

## Scripts

This skill includes executable scripts in `scripts/` that handle deterministic operations:

**preflight-check.sh** - Validates template repo state before cherry-picking
```bash
./scripts/preflight-check.sh <template-repo-path>
# Returns JSON with status: clean, dirty, wrong_branch, or behind
# Exit codes: 0=clean, 1=uncommitted changes, 2=wrong branch, 3=behind remote, 4=invalid path
```

Note: `preflight-check.sh` is intentionally **non-mutating**. It does **not** run `git fetch` or `git pull`. If remote sync status can't be verified from existing `origin/<default>` refs, it will warn and ask the operator to fetch/pull explicitly.

**list-commits.sh** - Lists commits with metadata (Claude does classification)
```bash
./scripts/list-commits.sh <remote/branch> [count]
# Returns JSON array with: sha, message, files[]
# NO classification - Claude inspects diffs and applies EXAMPLES.md guidance
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

Template repo path [e.g. ~/dev-projects/shared-agentic-template]:
```

Store the template path for use in Pre-Flight Checks.

Then prompt for commit scan depth:

```
How many recent commits to scan? [default: 10]:
```

Use this value for the git log command in Step 2.

## Prerequisites

A: **Dependencies**: `git`, `gh` (GitHub CLI), and `jq` must be installed. Run `./scripts/check-deps.sh` to verify and install if needed. Currently macOS only.

B: **Upstream template repo** exists locally (e.g., ~/dev-projects/shared-agentic-template)

C: **Project repo** was originally cloned/forked from the template


## Classification Guidance

Read **EXAMPLES.md** for detailed classification patterns with explanations.

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
- IDE settings (`.vscode/settings.json`)

**MAYBE** (needs changes or judgment):
- Scripts with hardcoded paths → Offer to parameterize
- Hooks that assume specific tools (biome, eslint) → Ask if template uses them
- `package.json` changes → Inspect diff: agentic packages = YES, project name = NO
- Mixed commits → Can they be split or generalized?

When uncertain, classify as MAYBE and present with an "Offer:" explaining what needs fixing or deciding.

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

### Step 2: List and classify commits

Run the list script to get commit metadata:

```bash
./scripts/list-commits.sh tmp-project/<branch> <N>
```

The script returns JSON with sha, message, and files for each commit. **Classification is done by Claude, not the script.**

For each commit, inspect the diff to classify:

```bash
git show <sha>
```

Apply **EXAMPLES.md** guidance to determine classification:

- **YES**: Cherry-pickable as-is (agents, skills, hooks, MCP configs, process docs)
- **MAYBE**: Needs changes or judgment (hardcoded paths, tool assumptions, mixed content)
- **NO**: Project-specific (feature code, PRDs, env files)

For MAYBE commits, determine the subtype:
- **refinable**: Has hardcoded paths/URLs/project names. Offer to parameterize.
- **needs judgment**: Tool or workflow assumptions. Ask operator.
- **skip**: Fundamentally project-specific, no modification helps.

### Step 3: Operator review (REQUIRED)

Present identified commits to operator for approval using the YES/MAYBE/NO format:

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
| <sha2>  | <message>                              | <judgment question>      |
|         | -> <file1>                             |                          |

NO (project-specific):
| SHA     | Message                        | Reason              |
|---------|--------------------------------|---------------------|
| <sha1>  | <message>                      | <reason>            |
|         | -> <file1>                     |                     |
|         | -> <file2>                     |                     |
| <sha2>  | <message>                      | <reason>            |
|         | -> <file1>                     |                     |

Proceed? Operator can respond naturally:
- "yes to all"
- "for MAYBE <sha>, parameterize it first"
- "skip the <description> or <sha>"
```

Do NOT proceed until operator confirms which commits to cherry-pick.

### Handling MAYBE commits

If operator asks to fix a MAYBE commit before cherry-picking:

1. **Pause the cherry-pick workflow**
2. **Switch to project repo**: `cd <project-repo>`
3. **Make the fix**: Parameterize paths, replace project names, etc.
4. **Present diff and commit message** for operator approval
5. **After approval**: Commit the fixed version
6. **Resume cherry-picking**: Return to template repo and continue

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

### Step 7: Return to project and secure upstream

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

### Script Failures

**preflight-check.sh failures**:
- Exit code 0: Clean state, ready to proceed
- Exit code 1 (dirty): Stash or commit changes, then retry
- Exit code 2 (wrong branch): Checkout default branch, then retry
- Exit code 3 (behind/diverged): Pull latest changes, then retry
- Exit code 4 (invalid path): Verify template path is correct

**list-commits.sh failures**:
- Exit code 1: Various errors including:
  - No remote/branch provided: Check command syntax
  - Invalid branch name: Only alphanumeric, /, -, _, . allowed
  - Invalid count: Must be positive integer ≤100
  - Remote branch not found: Run `git fetch tmp-project` first
  - Output size exceeds 512KB: Reduce commit count

**check-deps.sh failures**:
- Exit code 0: All dependencies available
- Exit code 1: Missing dependencies, user declined install
- Exit code 2: Installation failed - check network and brew status
- Exit code 3: Unsupported OS (currently macOS only)
- Common issues:
  - "brew not found": Install Homebrew first, then retry
  - "Missing git/gh/jq": Install manually or approve brew install

**conflict-backup.sh failures**:
- Exit code 0: Conflicts found and backed up successfully
- Exit code 1: No conflicts detected (not an error)
- Exit code 2: Not in a git repository
- Exit code 3: Backup creation failed - check disk space and permissions


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
