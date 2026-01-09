#!/usr/bin/env bash
#
# preflight-check.sh
# Validates template repo state before cherry-picking
#
# Platform: macOS only
# TODO: Add Windows and Linux cross-environment compatibility
#
# Usage: ./preflight-check.sh <template-repo-path>
# Exit codes:
#   0 - Clean state, ready to proceed
#   1 - Has uncommitted changes (needs stash)
#   2 - Not on default branch
#   3 - Behind remote (needs pull)
#   4 - Invalid path or not a git repo
#
# Output: JSON with status details

set -euo pipefail

TEMPLATE_PATH="${1:-}"

if [[ -z "$TEMPLATE_PATH" ]]; then
    echo '{"error": "No template path provided", "exit_code": 4}'
    exit 4
fi

if [[ ! -d "$TEMPLATE_PATH/.git" ]]; then
    echo '{"error": "Not a git repository", "path": "'"$TEMPLATE_PATH"'", "exit_code": 4}'
    exit 4
fi

cd "$TEMPLATE_PATH"

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

# Detect default branch (main or master)
DEFAULT_BRANCH=""
if git show-ref --verify --quiet refs/heads/main; then
    DEFAULT_BRANCH="main"
elif git show-ref --verify --quiet refs/heads/master; then
    DEFAULT_BRANCH="master"
else
    DEFAULT_BRANCH="$CURRENT_BRANCH"
fi

# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain)
if [[ -n "$UNCOMMITTED" ]]; then
    FILE_COUNT=$(echo "$UNCOMMITTED" | wc -l | tr -d ' ')
    echo '{"status": "dirty", "reason": "uncommitted_changes", "file_count": '"$FILE_COUNT"', "current_branch": "'"$CURRENT_BRANCH"'", "default_branch": "'"$DEFAULT_BRANCH"'", "exit_code": 1}'
    exit 1
fi

# Check if on default branch
if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]]; then
    echo '{"status": "wrong_branch", "reason": "not_on_default", "current_branch": "'"$CURRENT_BRANCH"'", "default_branch": "'"$DEFAULT_BRANCH"'", "exit_code": 2}'
    exit 2
fi

# Check if behind remote
git fetch origin "$DEFAULT_BRANCH" --quiet 2>/dev/null || true
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$DEFAULT_BRANCH" 2>/dev/null || echo "$LOCAL")

if [[ "$LOCAL" != "$REMOTE" ]]; then
    BEHIND_COUNT=$(git rev-list --count HEAD.."origin/$DEFAULT_BRANCH" 2>/dev/null || echo "0")
    if [[ "$BEHIND_COUNT" -gt 0 ]]; then
        echo '{"status": "behind", "reason": "needs_pull", "behind_count": '"$BEHIND_COUNT"', "current_branch": "'"$CURRENT_BRANCH"'", "default_branch": "'"$DEFAULT_BRANCH"'", "exit_code": 3}'
        exit 3
    fi
fi

# All checks passed
echo '{"status": "clean", "current_branch": "'"$CURRENT_BRANCH"'", "default_branch": "'"$DEFAULT_BRANCH"'", "exit_code": 0}'
exit 0
