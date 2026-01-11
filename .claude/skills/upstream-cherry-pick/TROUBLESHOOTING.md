# Troubleshooting & recovery (operator-facing)

This file contains the “deep/rare paths” so `SKILL.md` can stay lean. Keep this page stable and explicit; it’s used under stress.

## Interrupted cherry-pick

If the cherry-pick process is interrupted (Ctrl+C, crash, connection loss), check state before resuming:

```bash
cd <template-repo>
git status
```

If you see "You are currently cherry-picking commit..." or "Unmerged paths", you have an in-progress cherry-pick:

### Option A: Resume after fixing conflicts

```bash
# After manually resolving conflicts:
git add .
git cherry-pick --continue
```

### Option B: Abort and restart

```bash
git cherry-pick --abort

# Clean up temporary remote (best-effort)
git remote remove tmp-project 2>/dev/null || true

# Return to clean state (DANGEROUS: discards local changes)
git reset --hard origin/<default-branch>
```

### Option C: Skip problematic commit

```bash
git cherry-pick --skip
```

After recovery, verify:

```bash
git status
git log --oneline -5
```

## Preflight exit codes and common actions

`preflight-check.sh` is intentionally non-mutating (it will not run `git fetch` or `git pull`). Treat its JSON + exit codes as the source of truth.

Exit codes and typical operator actions:

- `0`: clean, safe to proceed (may include a `warning` in JSON)
- `1`: dirty
  - Decide: stash, commit, or abort workflow
- `2`: wrong branch or detached head
  - Switch to default branch before proceeding
- `3`: behind or diverged (based only on existing local `origin/<default>` ref)
  - Decide: fetch/pull explicitly (operator-confirmed) before proceeding
- `4`: invalid path / not a repo / missing dependency
  - Fix input or environment and re-run

## Script outputs & exit codes

Not all non-zero exits are “errors” (e.g. `conflict-backup.sh` uses exit code 1 to mean “no conflicts”).


