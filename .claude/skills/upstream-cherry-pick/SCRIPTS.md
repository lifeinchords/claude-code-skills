# Script reference (JSON outputs + exit codes)

This skill intentionally pushes deterministic operations into helper scripts. Claude should treat script output as the source of truth, especially exit codes and machine-readable JSON.

## `check-deps.sh`

Purpose: Verify required tools (`git`, `gh`, `jq`) are present; on macOS, optionally offer installation via Homebrew.

Exit codes:
- `0`: all deps present or installed successfully
- `1`: missing deps and operator declined install (or brew missing)
- `2`: installation failed
- `3`: unsupported OS (currently macOS-only installer)

Notes:
- Emits interactive prompts to **stderr**; final status is emitted as JSON on **stdout**.

## `preflight-check.sh <template-repo-path>`

Purpose: Validate template repo is ready to receive cherry-picks **without mutating repo state** (no fetch/pull).

Exit codes:
- `0`: clean / OK to proceed (may include a `warning` in JSON, e.g. missing `origin/<default>` ref)
- `1`: dirty (uncommitted changes present)
- `2`: wrong branch / detached head
- `3`: behind/diverged (based on existing local `origin/<default>` ref only)
- `4`: invalid path / not a repo / missing dependency (`jq`)

Notes:
- If the template repo lacks a usable `origin/<default>` ref, the script returns `0` with a warning rather than mutating state via `git fetch`.

## `list-commits.sh <remote/branch> [count]`

Purpose: Deterministically list commits (sha/message/files) for Claude to classify (NO classification inside the script).

Exit codes:
- `0`: success (JSON array)
- `1`: invalid input, missing dependency (`jq`), or branch not found

Notes:
- Output is a JSON array of objects `{sha, message, files[]}`.
- Enforces a max output size and may return a partial array with an `"error"` object if the limit is reached.

## `detect-mode.sh <remote/branch> [count]`

Purpose: Suggest `squash` vs `cherry-pick` based on the dispersion of touched paths across the commit set.

Exit codes:
- `0`: success (JSON object with `suggested_mode` and analysis fields)
- `1`: invalid input, missing dependency (`jq`), or branch not found

Notes:
- This is advisory only; operator chooses the mode.

## `conflict-backup.sh [commit-sha] [commit-message]`

Purpose: When a cherry-pick produces conflicts, collect conflicted files, back them up under `temp/merge-backups/YYYY-MM-DD/`, and return a structured JSON report.

Exit codes:
- `0`: conflicts found (report returned)
- `1`: no conflicts detected (NOT an error)
- `2`: not in a git repository
- `3`: backup creation failed or missing dependency (`jq`)

Notes:
- Designed for safety: rejects suspicious paths, skips symlinks, and records checksums when possible.


