#!/usr/bin/env bash
#
# list-commits.sh
# Lists commits with metadata for Claude to classify
#
# This script handles DETERMINISTIC operations only:
# - Fetching commit SHAs, messages, and file lists
# - Input validation and security checks
# - Structured JSON output
#
# CLASSIFICATION IS NOT DONE HERE. Claude reads this output,
# inspects diffs as needed, and applies EXAMPLES.md guidance
# to determine YES/MAYBE/NO for each commit.
#
# Platform: macOS (bash 3.2+), Linux
#
# Usage: ./list-commits.sh <remote/branch> [count]
# Example: ./list-commits.sh tmp-project/main 10
#
# Exit codes:
#   0 - Success
#   1 - Error (missing args, invalid input, branch not found)
#
# Output: JSON array with commit metadata (no classification)

set -euo pipefail
IFS=$'\n\t'

trap 'echo "Error in list-commits.sh at line $LINENO" >&2' ERR

# Check jq dependency before emitting any output
command -v jq &>/dev/null || { echo '{"error": "jq not installed"}'; exit 1; }

REMOTE_BRANCH="${1:-}"
COUNT="${2:-10}"

# Validate inputs
if [[ -z "$REMOTE_BRANCH" ]]; then
    echo '{"error": "No remote/branch provided. Usage: list-commits.sh <remote/branch> [count]"}'
    exit 1
fi

# Sanitize REMOTE_BRANCH: only allow safe characters
if [[ ! "$REMOTE_BRANCH" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
    jq -n --arg branch "$REMOTE_BRANCH" \
        '{"error": "Invalid branch name. Only alphanumeric, /, -, _, . allowed", "branch": $branch}'
    exit 1
fi

# Validate COUNT is a positive integer
if [[ ! "$COUNT" =~ ^[0-9]+$ ]] || [[ "$COUNT" -eq 0 ]]; then
    jq -n --arg count "$COUNT" \
        '{"error": "Count must be a positive integer", "count": $count}'
    exit 1
fi

# Cap COUNT to prevent overwhelming output
if [[ "$COUNT" -gt 100 ]]; then
    jq -n '{"error": "Count cannot exceed 100 commits"}'
    exit 1
fi

# Verify the remote branch exists
if ! git rev-parse --verify "$REMOTE_BRANCH^{commit}" &>/dev/null; then
    jq -n --arg branch "$REMOTE_BRANCH" \
        '{"error": "Remote branch not found. Run git fetch first.", "branch": $branch}'
    exit 1
fi

# Build JSON array of commits
echo '['

FIRST=true
OUTPUT_SIZE=0
MAX_OUTPUT_SIZE=$((512 * 1024))  # 512KB limit

while IFS= read -r line; do
    SHA=$(echo "$line" | cut -d' ' -f1)
    MESSAGE=$(echo "$line" | cut -d' ' -f2-)

    # Get files changed (NUL separator for safety, convert to JSON array)
    FILES_RAW=$(git diff-tree --no-commit-id --name-only -z -r "$SHA" 2>/dev/null | tr '\0' '\n' | grep -v '^$' || true)

    # Build files array
    FILES_JSON="[]"
    if [[ -n "$FILES_RAW" ]]; then
        FILES_JSON=$(echo "$FILES_RAW" | jq -R -s 'split("\n") | map(select(length > 0))')
    fi

    # Count files for safety check
    FILE_COUNT=$(echo "$FILES_JSON" | jq 'length')
    if [[ "$FILE_COUNT" -gt 100 ]]; then
        # Truncate large commits, note in output
        FILES_JSON=$(echo "$FILES_JSON" | jq '.[0:100] + ["... and more (truncated)"]')
    fi

    # Output separator
    if [[ "$FIRST" == "true" ]]; then
        FIRST=false
    else
        echo ","
    fi

    # Build commit object
    JSON_OBJECT=$(jq -n \
        --arg sha "$SHA" \
        --arg message "$MESSAGE" \
        --argjson files "$FILES_JSON" \
        '{sha: $sha, message: $message, files: $files}')

    # Check output size
    OBJECT_SIZE=${#JSON_OBJECT}
    ((OUTPUT_SIZE += OBJECT_SIZE)) || true

    if [[ $OUTPUT_SIZE -gt $MAX_OUTPUT_SIZE ]]; then
        echo ''
        echo '  {"error": "Output size limit reached", "partial": true}'
        echo ']'
        exit 0
    fi

    echo "  $JSON_OBJECT"

done < <(git log "$REMOTE_BRANCH" --oneline -"$COUNT" --reverse)

echo ''
echo ']'
