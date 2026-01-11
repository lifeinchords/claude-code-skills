#!/usr/bin/env bash
# shellcheck shell=bash
#
# detect-mode.sh
# Analyzes commits to suggest cherry-pick vs squash mode
#
# Deterministic detection:
# - If all commits share a common path prefix → suggest squash
# - If commits touch scattered paths → suggest cherry-pick
#
# Platform: macOS (bash 3.2+). Linux may work but is untested.
#
# Usage: ./detect-mode.sh <remote/branch> [count]
# Example: ./detect-mode.sh tmp-project/main 10
#
# Exit codes:
#   0 - Success
#   1 - Error (missing args, invalid input, branch not found)
#
# Output: JSON with mode suggestion and analysis

set -Eeuo pipefail
IFS=$'\n\t'

trap 'echo "Error in detect-mode.sh at line $LINENO" >&2; exit 1' ERR

# Check jq dependency
command -v jq &>/dev/null || { echo '{"error": "jq not installed"}'; exit 1; }

REMOTE_BRANCH="${1:-}"
COUNT="${2:-10}"

# Validate inputs
if [[ -z "$REMOTE_BRANCH" ]]; then
    echo '{"error": "No remote/branch provided. Usage: detect-mode.sh <remote/branch> [count]"}'
    exit 1
fi

# Sanitize REMOTE_BRANCH
if [[ ! "$REMOTE_BRANCH" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
    jq -n --arg branch "$REMOTE_BRANCH" \
        '{"error": "Invalid branch name", "branch": $branch}'
    exit 1
fi

# Validate COUNT
if [[ ! "$COUNT" =~ ^[0-9]+$ ]] || [[ "$COUNT" -eq 0 ]]; then
    jq -n --arg count "$COUNT" \
        '{"error": "Count must be a positive integer", "count": $count}'
    exit 1
fi

if [[ "$COUNT" -gt 100 ]]; then
    jq -n '{"error": "Count cannot exceed 100 commits"}'
    exit 1
fi

# Lock validated inputs
readonly REMOTE_BRANCH COUNT

# Verify the remote branch exists
if ! git rev-parse --verify "$REMOTE_BRANCH^{commit}" &>/dev/null; then
    jq -n --arg branch "$REMOTE_BRANCH" \
        '{"error": "Remote branch not found. Run git fetch first.", "branch": $branch}'
    exit 1
fi

# Collect all files from all commits
ALL_FILES=$(git log -n "$COUNT" --reverse --name-only --pretty=format: "$REMOTE_BRANCH" -- | grep -v '^$' | sort -u) || exit 1

if [[ -z "$ALL_FILES" ]]; then
    jq -n '{"error": "No files found in commits"}'
    exit 1
fi

# Find common prefix among all files
# Strategy: Take first file's directory, check if all files start with it
# Keep reducing until we find a common prefix or reach root

FIRST_FILE=$(head -1 <<< "$ALL_FILES")
COMMON_PREFIX=""

# Try progressively shorter prefixes
TEST_PREFIX=$(dirname "$FIRST_FILE")
while [[ "$TEST_PREFIX" != "." && -n "$TEST_PREFIX" ]]; do
    ALL_MATCH=true
    while IFS= read -r file; do
        if [[ "$file" != "$TEST_PREFIX"/* && "$file" != "$TEST_PREFIX" ]]; then
            ALL_MATCH=false
            break
        fi
    done <<< "$ALL_FILES"

    if [[ "$ALL_MATCH" == "true" ]]; then
        COMMON_PREFIX="$TEST_PREFIX"
        break
    fi

    TEST_PREFIX=$(dirname "$TEST_PREFIX")
done

# Count unique top-level directories
TOP_DIRS=$(cut -d'/' -f1 <<< "$ALL_FILES" | sort -u | wc -l | tr -d ' ')

# Get commit SHAs for reference
COMMIT_SHAS=$(git log -n "$COUNT" --reverse --pretty=format:"%h" "$REMOTE_BRANCH" -- | tr '\n' ' ')
FIRST_SHA=$(awk '{print $1}' <<< "$COMMIT_SHAS")
LAST_SHA=$(awk '{print $NF}' <<< "$COMMIT_SHAS")

# Get file list as JSON array
FILES_JSON=$(jq -R -s 'split("\n") | map(select(length > 0))' <<< "$ALL_FILES")
FILE_COUNT=$(jq 'length' <<< "$FILES_JSON")

# Determine suggested mode
if [[ -n "$COMMON_PREFIX" && "$COMMON_PREFIX" != "." ]]; then
    SUGGESTED_MODE="squash"
    REASON="All $COUNT commits share common prefix: $COMMON_PREFIX/"
elif [[ "$TOP_DIRS" -le 2 ]]; then
    SUGGESTED_MODE="squash"
    REASON="Commits touch only $TOP_DIRS top-level directories"
else
    SUGGESTED_MODE="cherry-pick"
    REASON="Commits touch $TOP_DIRS different top-level directories"
fi

# Build output
jq -n \
    --arg mode "$SUGGESTED_MODE" \
    --arg reason "$REASON" \
    --arg prefix "$COMMON_PREFIX" \
    --argjson top_dirs "$TOP_DIRS" \
    --argjson commit_count "$COUNT" \
    --arg first_sha "$FIRST_SHA" \
    --arg last_sha "$LAST_SHA" \
    --argjson file_count "$FILE_COUNT" \
    --argjson files "$FILES_JSON" \
    '{
        suggested_mode: $mode,
        reason: $reason,
        common_prefix: $prefix,
        top_level_dirs: $top_dirs,
        commit_count: $commit_count,
        first_sha: $first_sha,
        last_sha: $last_sha,
        file_count: $file_count,
        files: $files
    }'
