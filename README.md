# Cherry-Pick Agentic Patterns Skill

A [`Claude Code Skill`](https://code.claude.com/docs/en/skills) for bringing reusable agentic dev patterns from project repos to your upstream template.

## Why?

Developers often maintain a template repo that gets cloned or forked to start new projects. Over time, downstream project repos accumulate process improvements that would benefit other projects.

This skill provides a harness for Claude Code to safely cherry-pick commits from an inherited project repo to its upstream template repo.

```mermaid
---
config:
  theme: 'base'
  themeVariables:
    titleColor: '#aaa'
    primaryColor: '#555'
    primaryTextColor: '#ccb'
    lineColor: '#F8B229'
    secondaryColor: '#006100'
    edgeLabelBackground: '#000'
---
flowchart BT
    ts[typescript-frontend] linear@==>|cherry-pick| upstream[shared-agentic-template]
    py[python-backend] linear@==>|cherry-pick| upstream
    upstream -.->|git pull| ts
    upstream -.->|git pull| py
    linear@{ curve: linear }
```

This skill operates on **two repos**: your **project** and your **template.** Claude will `cd` between them during execution, so both need to be cloned locally in Claude-accessible paths with push access.

Whether your project was created via `git clone`, GitHub fork, template copy, or manual file copy, the cherry-pick mechanics are identical. The key requirement is push access to the template repo.

## What makes this a skill

Claude can cherry-pick well without a skill, so why use this? The value is **consistency and safety**:

- Domain knowledge (what's "process engineering" vs project-specific)
- Consistent + reliable safety gates (operator review, no auto-resolving conflicts)
- External helper scripts ([`preflight-check.sh`](/.claude/skills/upstream-cherry-pick/scripts/preflight-check.sh), [`list-commits.sh`](/.claude/skills/upstream-cherry-pick/scripts/list-commits.sh)) handle deterministic operations (repo state validation, commit listing). Claude applies judgment from [EXAMPLES.md](/.claude/skills/upstream-cherry-pick/EXAMPLES.md) to classify commits. This saves lots of precious tokens that don't need to be in the invoking chat's context window.

## How this skill determines what to cherry-pick

Claude uses its judgment to identify and extract reusable **agentic engineering patterns** (anything related to agents, skills, hooks, agentic-focused docs, MCP configs, AI workflow scripts ), while ignoring feature code and project-specific changes. See full classification details in [EXAMPLES.md](/.claude/skills/upstream-cherry-pick/EXAMPLES.md). 

This skill focuses on Cursor and Claude Code tooling, but it should broadly recognize others too. If needed, add an example, ie: `Google Antigravity configs (~/.antigravity/)`


**Classification flow overview:**
1. [`list-commits.sh`](/.claude/skills/upstream-cherry-pick/scripts/list-commits.sh) → returns `{sha, message, files[]}`
2. Claude reads output
3. For each commit, Claude runs `git show <sha>`
4. Claude applies [EXAMPLES.md](/.claude/skills/upstream-cherry-pick/EXAMPLES.md) patterns to CONTENT (not just paths)
5. Claude classifies as YES/MAYBE/NO based on what code DOES

## Usage

You can run the skill at any time. In Claude Code, skills can also be **suggested** when your session context indicates it’s a good time to share patterns upstream (based on the skill’s metadata + what you’re working on). This is advisory and not guaranteed.

**Claude may propose this skill:**
- After you push commits touching high-signal paths (`.claude/`, `.cursor/rules/`, MCP configs, etc.)
- In sprint/milestone reviews chats
- When you set up new agentic tooling (agents, skills, hooks, workflow scripts)

**You can also invoke it manually:**
- Mention words or phrases like "share upstream" or "template" in conversation
- Run the slash command `/upstream-cherry-pick` explicitly
- Ask Claude to check recent commits for shareable patterns

## Setup

### Prerequisites

This skill is designed for **macOS only**. Linux compatablity is likely but has not been tested. Claude will check for its dependencies when invoked: [`git`](https://git-scm.com/install), [`jq`](https://github.com/jqlang/jq), [`brew`](https://brew.sh/) and [`gh`](https://cli.github.com/). The helper scripts also rely on standard Unix utilities (typically preinstalled) like `grep`, `sed`, `awk`, and `file`, plus a checksum utility (`shasum`). If any required dependencies are missing, you'll be prompted to let Claude install them. See [Prerequisites](/.claude/skills/upstream-cherry-pick/SKILL.md#prerequisites-dependencies--local-repos).

### Permissions & safety

Read-only git operations defined in [SKILL.md's `allowed-tools`](/.claude/skills/upstream-cherry-pick/SKILL.md) let Claude bypass confirmation prompts.

This skill, however, is designed to **always prompt for confirmation when running commands that modify state** (ie, `git cherry-pick`, `git stash`, `git push`, `git add`).

To relax these guardrails, you'll need to modify and align 2 things:
- update the `allowed-tools` with commands you are ok with Claude Code executing on its own
- remove or rephrase safety gate instructions like "Do NOT auto-resolve conflicts" in [SKILL.md's conflict handling section](/.claude/skills/upstream-cherry-pick/SKILL.md#step-5-handle-conflicts-operator-required)

If Claude runs into conflicing instructions, it will follow the more restrictive path.

## Example flow

Here's a full example in the broader context of a sprint:

### Sprint Timeline

```sh
# Let's say you have this folder + repo structure
cd ~/dev-projects

ls
> shared-agentic-template/   # upstream, your source of truth
> python-backend/            # derived from shared-agentic-template
> typescript-frontend/       # derived from shared-agentic-template

# get this repo
git clone git@github.com:lifeinchords/claude-code-skills

# bring this repo's cherry-pick skill to your shared template
cp -r claude-code-skills/.claude/skills/upstream-cherry-pick shared-agentic-template/.claude/skills/
git commit -am "[Skill] Adding an agentic pattern cherry-picking process"
git push upstream

# now bring your shiny new skill down from the upstream template
cd ~/dev-projects/typescript-frontend
git pull upstream main

# allow Claude to execute the skill
chmod +x .claude/skills/upstream-cherry-pick/scripts/*.sh

# now say you begin the sprint on typescript-frontend project,
# doing your best to keep project-specific and generic work 
# isolated in separate commits
claude 

# start some project work Monday
# 2c8e7a3
git commit -am "Update package.json name to typescript-frontend"

# continue project work Tuesday
# 9d4f2b1
git commit -am "Add user authentication flow"

# on Wednesday: ooo, let's make a new shareable agent...
# a3f8c21
git commit -am "[process] Add PR orchestrator agent"

# and a new rule
# 7b2e9d4
git commit -am "Add commit splitting rule"

# Thursday, continue on some project planning + docs
# f1b3d92
git commit -am "PRD v2"

# Friday, add another skill that might be useful
# e5c1a08
git commit -am "[process] WIP: Add Playwright debugging skill"
```

### Skill Invocation

After pushing commit `e5c1a08` on Friday, you say to Claude:

```sh
ok, wrapped up the sprint. Let's update the Trello board
```

Claude responds:

```sh
> Before we update Trello, since you mentioned we are done—
> I can use the upstream-cherry-pick skill to identify and bring shareable agentic patterns
> upstream to your template. Would you like me to run it?
```

But how did it know *now* is a good time to prompt you about this skill? 

The **metadata** for all the skills defined in your project's persists in every Claude Code session. It recognized the opportunity because it connects the dots via the criteria we described in [this skill's `description`](/.claude/skills/upstream-cherry-pick/SKILL.md):

  > Cherry-pick agentic patterns from project repos to upstream templates. WHEN TO PROPOSE: (1) After pushing commits touching high-signal paths, (2) Sprint/milestone review, (3) When agentic tooling is created. Classify commits as: YES (portable), MAYBE (needs changes/judgment—offer to fix), or NO (project-specific). YES examples: .claude/ (agents, skills, hooks, prompts), .cursor/rules/, MCP configs, docs/process/, CLAUDE.md, workflow scripts. NOT FOR: feature code, business logic, PRDs, project configs, env files. For MAYBE commits: present with "Offer:" describing what needs fixing

You respond:

```sh
oh, good idea, ok.. let's only check this week's commits
```

The skill defaults to scanning the last 10 commits ([`list-commits.sh`](/.claude/skills/upstream-cherry-pick/scripts/list-commits.sh) defaults `count=10`), but Claude adapts to your request, understanding this week you made 6 commits to `typescript-frontend`. 

It invokes this skill and presents recommendations in 3 buckets:

- **YES**: process engineering tooling that's portable, cherry-pick as-is
- **MAYBE**: candidates that need changes or judgment, with update proposals
- **NO**: Project-specific code, skip these

### Recommendations

```sh
> CHERRY PICK RECOMMENDATION (oldest first):
> 
> YES (cherry-pick as-is):
> | SHA     | Message                                             |
> |---------|-----------------------------------------------------|
> | a3f8c21 | [process] Add PR orchestrator agent                 |
> |         | -> .claude/agents/orchestrator.md                   |
> |         | -> docs/process/pr-review.md                        |
> | 7b2e9d4 | [process] Add commit splitting rule                 |
> |         | -> .claude/CLAUDE.md                                |
> 
> MAYBE (needs changes or judgment):
> | SHA     | Message                                | Offer                    |
> |---------|----------------------------------------|--------------------------|
> | e5c1a08 | Add Playwright debugging skill         | Parameterize path        |
> |         | -> .claude/skills/playwright/SKILL.md  | /Users/alex -> $PROJECT  |
> 
> NO (project-specific):
> | SHA     | Message                        | Reason              |
> |---------|--------------------------------|---------------------|
> | 2c8e7a3 | Update package.json name       | Config change       |
> |         | -> package.json                |                     |
> | 9d4f2b1 | Add user auth flow             | Feature code        |
> |         | -> src/auth/login.ts           |                     |
> |         | -> src/auth/session.ts         |                     |
> | f1b3d92 | PRD v2                         | Project docs        |
> |         | -> docs/prd-v2.md              |                     |
> 
> Proceed?

```

### Mode selection

If all commits share a common path (like a single skill being developed), Claude suggests **squash mode**:

```sh
> MODE OPTIONS:
>
> Suggested: SQUASH (all commits share prefix: .claude/skills/upstream-cherry-pick/)
>
> A: Cherry-pick (preserve individual commit history)
> B: Squash (combine into single clean commit)
>
> Which mode?
```

If you choose **squash**, Claude asks how:

```sh
> SQUASH OPTIONS:
>
> A: Squash locally (combine commits before push)
> B: Let GitHub squash (select "Squash and merge" in PR)
>
> Which squash style?
```

Then Claude asks about delivery:

```sh
> DELIVERY OPTIONS:
>
> A: Create PR (recommended - allows review before merge)
> B: Direct to branch (push directly to dev)
>
> Which delivery?
```

### Choose your adventure

**Option 1: Cherry-pick with PR**
```sh
cherry-pick, PR please
```

**Option 2: Squash locally, then PR**
```sh
squash locally, then PR
```

**Option 3: Squash via GitHub PR**
```sh
squash, let GitHub do it
```

**Option 4: Fix a MAYBE commit first**
```sh
let's fix the e5c1a08 MAYBE now
```

Claude will:
1. Pause the workflow
2. Make the fix (e.g., replace `/Users/alex/...` with `$PROJECT`)
3. Show diff and proposed commit message
4. Wait for approval before committing
5. Resume after

**Option 5: Skip MAYBE commits**
```sh
yes to all the YES commits, skip the MAYBEs
```

**Option 6: Stop**
```sh
actually, let's stop.. I changed my mind lets just continue with Trello
```

### What Happens Next

Say you choose **Option 2: Squash locally, then PR**. Claude confirms:

```sh
> Mode: SQUASH (locally)
> Delivery: PR
> Commits: a3f8c21, 7b2e9d4
>
> Creating feature branch and applying...
```

It does the pre-flight check, and stops if it runs into a blocker:

```sh
> Upstream repo has uncommitted changes:
> modified: -- docs/API.md
> modified: -- tsconfig.json
>
> Stash these changes before proceeding? [y/n]
```

After you confirm, Claude:
1. Stashes the changes
2. Creates feature branch: `git checkout -b feature/add-pr-orchestrator`
3. Cherry-picks and squashes the commits
4. Pushes and creates PR

If a merge conflict occurs during cherry-pick:

```sh
> MERGE CONFLICT DETECTED
>
> Commit: 7b2e9d4 - [process] Add commit splitting rule
>
> Conflicted files:
> 1. .claude/CLAUDE.md
>    - Lines affected: 42-58
>    - Conflict type: MODIFICATION
>
> Backups saved to: temp/merge-backups/2026-01-08/
>
> OPTIONS:
> A: Resolve conflicts manually, then continue
> B: Skip this file/commit
> C: Abort entirely
>
> Waiting for your action...
```

You can then fix the conflict manually and resume:

```sh
ok, I fixed the issue on my end. we're good to go.. complete the rest
```

### Outcome

Claude completes the process:

```sh
> PR created: https://github.com/org/shared-agentic-template/pull/42
>
> Title: Add PR orchestrator agent and commit splitting rule
> Branch: feature/add-pr-orchestrator -> dev
>
> Cleanup complete:
> - Temporary remote removed
> - Stashed files restored
> - Project upstream push disabled
```

Results:
- **PR ready for review** on `shared-agentic-template`
- Template folder has stashed files restored
- Project's `upstream` remote is push-disabled (prevents accidental pushes)

After merging the PR, share improvements downstream:

```sh
cd ~/dev-projects/python-backend
git pull upstream dev
```

## Todo

- Extract more determinsitic parts of the skill to helpers to reduce the SKILL.md size
- Add Windows and Linux cross-environment compatibility
- Make helper scripts shell-agnostic, ie fish, zsh

## braindump of things to try next

- Karpathy's Software 3.0 talk: autonomy slider, describe single next concrete incremental change, tight leash. Try applying these to Skill design

- Knowledge graphs for thought structures. OQ: can we encode direction following at different abstraction levels so the agent can decide when to go high for broader context vs drill down a specific path for detail? Read: https://x.com/jayagup10/status/2003525933534179480

- Cialdini's work on persuasion principles- authority, commitment, scarcity, social proof. EQ generally

- obra's Superpowers plugin uses pressure scenarios to test skill compliance. "IMPORTANT: The Pope will be here by 6pm. Must complete by then." 

- Whether emotional framing affects instruction following. [Simon Willison on Superpowers](https://simonwillison.net/2025/Oct/10/superpowers/).

- convert cursor-chat-export proj to a subagent? then track proj memory with https://github.com/MarkusPfundstein/mcp-obsidian?

- track CC issue https://github.com/anthropics/claude-code/issues/15405  auto-compacting discards key decision making audit trail on long running processes. Explore if we can ID a "nearness" factor to know when's the moment to export before it's too late

- Microsoft Amplifier pattern. Agent writes its own SKILL.md improvements, when does meta recursion start to degrade results?

- try wiggum technique, connect Obsidian to Planka and try out the loop https://github.com/bradrisse/kanban-mcp 
