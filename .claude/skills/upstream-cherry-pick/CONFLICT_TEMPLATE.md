# MERGE CONFLICT TEMPLATE (operator-facing)
#
# This file intentionally contains a strict, copy/paste-friendly output format.
# Keep it stable so operators learn to trust it.
#

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



