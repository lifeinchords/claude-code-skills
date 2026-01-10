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

# Use jq for all JSON output to ensure proper escaping
if [[ -z "$TEMPLATE_PATH" ]]; then
    jq -n '{"error": "No template path provided", "exit_code": 4}'
    exit 4
fi

if [[ ! -d "$TEMPLATE_PATH/.git" ]]; then
    jq -n --arg path "$TEMPLATE_PATH" '{"error": "Not a git repository", "path": $path, "exit_code": 4}'
    exit 4
fi

cd "$TEMPLATE_PATH"

# Get current branch - handles detached HEAD state
CURRENT_BRANCH=$(git branch --show-current)

# Handle detached HEAD state (empty string returned)
if [[ -z "$CURRENT_BRANCH" ]]; then
    jq -n --arg head "$(git rev-parse --short HEAD)" \
        '{"error": "Detached HEAD state - not on any branch", "commit": $head, "exit_code": 2}'
    exit 2
fi

# Detect default branch (main or master)
DEFAULT_BRANCH=""
if git show-ref --verify --quiet refs/heads/main; then
    DEFAULT_BRANCH="main"
elif git show-ref --verify --quiet refs/heads/master; then
    DEFAULT_BRANCH="master"
else
    # If neither main nor master exists, use current branch as default
    DEFAULT_BRANCH="$CURRENT_BRANCH"
fi

# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain)
if [[ -n "$UNCOMMITTED" ]]; then
    FILE_COUNT=$(echo "$UNCOMMITTED" | wc -l | tr -d ' ')
    jq -n \
        --arg status "dirty" \
        --arg reason "uncommitted_changes" \
        --argjson file_count "$FILE_COUNT" \
        --arg current_branch "$CURRENT_BRANCH" \
        --arg default_branch "$DEFAULT_BRANCH" \
        --argjson exit_code 1 \
        '{status: $status, reason: $reason, file_count: $file_count, current_branch: $current_branch, default_branch: $default_branch, exit_code: $exit_code}'
    exit 1
fi

# Check if on default branch
if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]]; then
    jq -n \
        --arg status "wrong_branch" \
        --arg reason "not_on_default" \
        --arg current_branch "$CURRENT_BRANCH" \
        --arg default_branch "$DEFAULT_BRANCH" \
        --argjson exit_code 2 \
        '{status: $status, reason: $reason, current_branch: $current_branch, default_branch: $default_branch, exit_code: $exit_code}'
    exit 2
fi

# Check if behind remote
# First verify that 'origin' remote exists
if ! git remote | grep -q "^origin$"; then
    jq -n \
        --arg warning "No 'origin' remote found - skipping sync check" \
        --arg current_branch "$CURRENT_BRANCH" \
        --arg default_branch "$DEFAULT_BRANCH" \
        '{status: "clean", warning: $warning, current_branch: $current_branch, default_branch: $default_branch, exit_code: 0}'
    exit 0
fi

# Fetch from origin - do NOT hide errors as they indicate real problems
# (network issues, authentication failures, etc.)
if ! git fetch origin "$DEFAULT_BRANCH" --quiet 2>&1; then
    jq -n \
        --arg error "Failed to fetch from origin - check network and authentication" \
        --arg current_branch "$CURRENT_BRANCH" \
        --arg default_branch "$DEFAULT_BRANCH" \
        '{status: "fetch_failed", error: $error, current_branch: $current_branch, default_branch: $default_branch, exit_code: 3}'
    exit 3
fi

LOCAL=$(git rev-parse HEAD)

# Check if remote branch exists after fetch
if ! git rev-parse --verify "origin/$DEFAULT_BRANCH" &>/dev/null; then
    jq -n \
        --arg error "Remote branch origin/$DEFAULT_BRANCH does not exist" \
        --arg current_branch "$CURRENT_BRANCH" \
        --arg default_branch "$DEFAULT_BRANCH" \
        '{status: "no_remote_branch", error: $error, current_branch: $current_branch, default_branch: $default_branch, exit_code: 3}'
    exit 3
fi

REMOTE=$(git rev-parse "origin/$DEFAULT_BRANCH")

# Check if branches have diverged (local ahead, behind, or both)
if [[ "$LOCAL" != "$REMOTE" ]]; then
    BEHIND_COUNT=$(git rev-list --count HEAD.."origin/$DEFAULT_BRANCH" 2>/dev/null || echo "0")
    AHEAD_COUNT=$(git rev-list --count "origin/$DEFAULT_BRANCH"..HEAD 2>/dev/null || echo "0")

    if [[ "$BEHIND_COUNT" -gt 0 && "$AHEAD_COUNT" -gt 0 ]]; then
        # Branches have diverged
        jq -n \
            --arg status "diverged" \
            --arg reason "local_and_remote_have_different_commits" \
            --argjson behind_count "$BEHIND_COUNT" \
            --argjson ahead_count "$AHEAD_COUNT" \
            --arg current_branch "$CURRENT_BRANCH" \
            --arg default_branch "$DEFAULT_BRANCH" \
            --argjson exit_code 3 \
            '{status: $status, reason: $reason, behind_count: $behind_count, ahead_count: $ahead_count, current_branch: $current_branch, default_branch: $default_branch, exit_code: $exit_code}'
        exit 3
    elif [[ "$BEHIND_COUNT" -gt 0 ]]; then
        # Behind remote
        jq -n \
            --arg status "behind" \
            --arg reason "needs_pull" \
            --argjson behind_count "$BEHIND_COUNT" \
            --arg current_branch "$CURRENT_BRANCH" \
            --arg default_branch "$DEFAULT_BRANCH" \
            --argjson exit_code 3 \
            '{status: $status, reason: $reason, behind_count: $behind_count, current_branch: $current_branch, default_branch: $default_branch, exit_code: $exit_code}'
        exit 3
    elif [[ "$AHEAD_COUNT" -gt 0 ]]; then
        # Ahead of remote - warn but allow (unpushed commits)
        jq -n \
            --arg status "clean" \
            --arg warning "Local branch is ahead of remote by commits (unpushed)" \
            --argjson ahead_count "$AHEAD_COUNT" \
            --arg current_branch "$CURRENT_BRANCH" \
            --arg default_branch "$DEFAULT_BRANCH" \
            --argjson exit_code 0 \
            '{status: $status, warning: $warning, ahead_count: $ahead_count, current_branch: $current_branch, default_branch: $default_branch, exit_code: $exit_code}'
        exit 0
    fi
fi

# All checks passed
jq -n \
    --arg status "clean" \
    --arg current_branch "$CURRENT_BRANCH" \
    --arg default_branch "$DEFAULT_BRANCH" \
    --argjson exit_code 0 \
    '{status: $status, current_branch: $current_branch, default_branch: $default_branch, exit_code: $exit_code}'
exit 0
