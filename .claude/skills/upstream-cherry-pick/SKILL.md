---
name: upstream-cherry-pick
description: A safe, guided process for bringing reusable agentic improvements from a project repo (ie, agents, skills, scripts, docs) to its upstream shared template
---

## Purpose

Many teams maintain a template repository that gets cloned or
forked to start new projects. Over time, project repos accumulate improvements
that should flow back to the template for other projects to inherit.

This skill guides Claude through safely cherry-picking commits from a project
repo to the upstream template repo.

## Dependencies

- `gh` - GitHub CLI for repo verification and commit preview
- `jq` - JSON processor for parsing API responses


## Invocation

When this skill is triggered, confirm operator understands the setup:

```
This skill operates on TWO directories:

1. Your project repo (where you are now)
2. Your template repo (where cherry-picks will be applied)

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

A: Upstream template repo exists locally (e.g., ~/Code/template)

B: Project repo was originally cloned/forked from the template

C: Commits follow a convention distinguishing generic vs project-specific:
   (1) Generic: process docs, agents, skills, scripts usable in any project
   (2) Project-specific: configs, feature code, project names, PRDs


## Pre-Flight Checks

Before cherry-picking, always verify clean state in the template repo:

```bash
# Navigate to template repo
cd <template-repo>

# Check for uncommitted changes that could conflict
git status

# If changes exist, stash them with descriptive message
# Format: pre-cherry-pick-YYYY-MM-DD-HHMM
git stash push -u -m "pre-cherry-pick-$(date +%Y-%m-%d-%H%M)"

# Ensure on correct branch and up to date
git checkout <default-branch>
git pull origin <default-branch>
```


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

Scan the last N commits (from invocation input) to classify:

```bash
# List last N commits with files changed for classification
# Replace <N> with value from invocation (default: 10)
git log tmp-project/<branch> --oneline -<N> --stat | head -60

# View specific commit details when unsure
git show --stat --oneline <sha>
```

Classify each commit:

- GENERIC: agents, skills, scripts, docs/process/, template rules
- PROJECT-SPECIFIC: project name references, configs, feature code, PRDs

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

EXCLUDED (project-specific):

| SHA     | Message                        | Reason        |
|---------|--------------------------------|---------------|
| <sha1>  | <message>                      | <reason>      |
|         | -> <file1>                     |               |
|         | -> <file2>                     |               |
| <sha2>  | <message>                      | <reason>      |
|         | -> <file1>                     |               |

Proceed with cherry-pick? [y/n]
```

Do NOT proceed until operator confirms the commit list is correct.

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

```bash
# Check which files have conflicts
git status

# List only the conflicted file paths
git diff --name-only --diff-filter=U
```

Create backup before operator resolves:

```bash
# Create dated backup directory
mkdir -p temp/merge-backups/$(date +%Y-%m-%d)

# Copy all conflicted files to backup location
for f in $(git diff --name-only --diff-filter=U); do
  mkdir -p "temp/merge-backups/$(date +%Y-%m-%d)/$(dirname $f)"
  cp "$f" "temp/merge-backups/$(date +%Y-%m-%d)/$f"
done
```

Analyze conflicts and present summary to operator:

```bash
# Show line numbers where conflicts occur in each file
for f in $(git diff --name-only --diff-filter=U); do
  echo "=== $f ==="
  grep -n "<<<<<<< HEAD" "$f" | head -5
done

# Show full diff of conflicted sections
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


## Identifying Generic Commits

Commits are generic if they:

A: Modify files in .claude/agents/ (not project-specific configs)

B: Add skills to .claude/skills/ that are reusable

C: Update docs/process reference materials

D: Change template rules applicable to any project

E: Add scripts in tools/ that are project-agnostic

Commits are project-specific if they:

A: Reference project name in code or configs

B: Modify project-specific configs (package.json name, workspace file)

C: Add project-specific PRDs or feature docs


## Commit Message Convention

When making commits intended for upstream:

```
[process] Add <description>
```

When making project-specific commits:

```
[<project-name>] Add <description>
```


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
