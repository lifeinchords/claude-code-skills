# Checklist (operator-facing)

## Rigor levels

**Default enforcement**: required

When `required`:
- Always stash uncommitted changes in template first
- Always create backups for conflicts under `temp/merge-backups/`
- Always verify remote cleanup after cherry-pick
- Never force push to template
- Never auto-resolve merge conflicts — stop for operator

When `exploratory`:
- May skip backup creation for simple cherry-picks

## Cherry-pick workflow checklist

- [ ] Template repo has no uncommitted changes (stashed if needed)
- [ ] On default branch in template
- [ ] Pulled latest from origin (operator-confirmed)
- [ ] Temporary remote added (operator-confirmed)
- [ ] Commits classified as YES/MAYBE/NO (per `EXAMPLES.md`)
- [ ] Operator reviewed and approved commit list + mode + delivery
- [ ] Cherry-pick completed without errors
- [ ] Conflicts backed up and resolved (if any)
- [ ] Pushed to template (operator-confirmed)
- [ ] Temporary remote removed (operator-confirmed)
- [ ] Restore stashed changes (git stash pop) (operator-confirmed)
- [ ] Project upstream push still DISABLED


