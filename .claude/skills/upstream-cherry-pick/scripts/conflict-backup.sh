#!/usr/bin/env bash
#
# conflict-backup.sh
# Detects merge conflicts, creates backups, and outputs structured analysis
#
# Platform: macOS only
# TODO: Add Windows and Linux cross-environment compatibility
#
# Usage: ./conflict-backup.sh [commit-sha] [commit-message]
# Exit codes:
#   0 - Conflicts found and backed up
#   1 - No conflicts detected
#   2 - Not in a git repository
#   3 - Backup creation failed
#
# Output: JSON with conflict details and backup location

set -euo pipefail
IFS=$'\n\t'

# Error trap for debugging
trap 'echo "Error in conflict-backup.sh at line $LINENO" >&2' ERR

COMMIT_SHA="${1:-unknown}"
COMMIT_MESSAGE="${2:-}"

# Verify we're in a git repo
if ! git rev-parse --git-dir &>/dev/null; then
    jq -n '{"status": "error", "message": "Not a git repository", "exit_code": 2}'
    exit 2
fi

# Get conflicted files
CONFLICTED_FILES=$(git diff --name-only --diff-filter=U 2>/dev/null || true)

if [[ -z "$CONFLICTED_FILES" ]]; then
    jq -n '{"status": "no_conflicts", "message": "No merge conflicts detected", "exit_code": 1}'
    exit 1
fi

# Create dated backup directory
BACKUP_DATE=$(date +%Y-%m-%d)
BACKUP_DIR="temp/merge-backups/$BACKUP_DATE"

if ! mkdir -p "$BACKUP_DIR"; then
    jq -n --arg dir "$BACKUP_DIR" \
        '{"status": "error", "message": "Failed to create backup directory", "backup_dir": $dir, "exit_code": 3}'
    exit 3
fi

# Build JSON array of conflicts using jq
CONFLICTS_JSON="[]"
BACKUP_COUNT=0
BACKUP_FAILED=()

while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    # Security: Validate file path doesn't contain traversal sequences
    if [[ "$file" =~ \.\. ]]; then
        jq -n --arg file "$file" \
            '{"status": "error", "message": "Invalid file path contains traversal sequence", "file": $file, "exit_code": 3}' >&2
        BACKUP_FAILED+=("$file")
        continue
    fi

    # Security: Reject symlinks (prevent following malicious links to sensitive files)
    if [[ -L "$file" ]]; then
        jq -n --arg file "$file" \
            '{"status": "warning", "message": "Skipping symlink", "file": $file}' >&2
        BACKUP_FAILED+=("$file")
        continue
    fi

    # Create parent directory in backup location
    FILE_DIR=$(dirname -- "$file")
    if ! mkdir -p -- "$BACKUP_DIR/$FILE_DIR" 2>/dev/null; then
        BACKUP_FAILED+=("$file")
        continue
    fi

    # Verify directory was created and isn't a symlink (prevent race condition attacks)
    if [[ ! -d "$BACKUP_DIR/$FILE_DIR" ]] || [[ -L "$BACKUP_DIR/$FILE_DIR" ]]; then
        jq -n --arg dir "$BACKUP_DIR/$FILE_DIR" \
            '{"status": "error", "message": "Backup directory validation failed", "dir": $dir}' >&2
        BACKUP_FAILED+=("$file")
        continue
    fi

    # Copy file to backup (do NOT preserve symlinks, copy content)
    BACKED_UP="false"
    if cp -- "$file" "$BACKUP_DIR/$file" 2>/dev/null; then
        BACKED_UP="true"
        ((BACKUP_COUNT++))
    else
        BACKUP_FAILED+=("$file")
    fi

    # Find conflict line numbers (where <<<<<<< HEAD appears)
    # Handle binary files gracefully
    if file -- "$file" | grep -q "text"; then
        CONFLICT_LINES=$(grep -n "<<<<<<< HEAD" -- "$file" 2>/dev/null | cut -d: -f1 | tr '\n' ',' | sed 's/,$//' || echo "")
    else
        CONFLICT_LINES="binary_file"
    fi
    [[ -z "$CONFLICT_LINES" ]] && CONFLICT_LINES="unknown"

    # Determine conflict type by analyzing the file
    CONFLICT_TYPE="MODIFICATION"  # default

    # Check if file exists in HEAD
    if ! git show HEAD:"$file" &>/dev/null; then
        CONFLICT_TYPE="ADDITION"
    else
        # Check if incoming side deleted the file
        # (conflict markers present but file was deleted on one side)
        if [[ "$CONFLICT_LINES" != "binary_file" ]] && grep -q "<<<<<<< HEAD" -- "$file" && grep -q ">>>>>>>" -- "$file"; then
            # Check the content between markers
            HEAD_CONTENT=$(sed -n '/<<<<<<< HEAD/,/=======/p' -- "$file" 2>/dev/null | grep -v "<<<<<<< HEAD" | grep -v "=======" || true)
            INCOMING_CONTENT=$(sed -n '/=======/,/>>>>>>>/p' -- "$file" 2>/dev/null | grep -v "=======" | grep -v ">>>>>>>" || true)

            # Check for whitespace-only content (not truly empty)
            if [[ -z "$(echo "$HEAD_CONTENT" | tr -d '[:space:]')" ]]; then
                CONFLICT_TYPE="DELETION"  # HEAD side is empty/whitespace-only
            elif [[ -z "$(echo "$INCOMING_CONTENT" | tr -d '[:space:]')" ]]; then
                CONFLICT_TYPE="DELETION"  # Incoming side is empty/whitespace-only
            fi
        fi
    fi

    # Use jq to build conflict object and append to array
    CONFLICTS_JSON=$(jq -n \
        --argjson conflicts "$CONFLICTS_JSON" \
        --arg file "$file" \
        --arg lines "$CONFLICT_LINES" \
        --arg type "$CONFLICT_TYPE" \
        --argjson backed_up "$BACKED_UP" \
        '$conflicts + [{file: $file, lines: $lines, type: $type, backed_up: $backed_up}]')

done <<< "$CONFLICTED_FILES"

# Count total conflicts
CONFLICT_COUNT=$(echo "$CONFLICTED_FILES" | wc -l | tr -d ' ')

# Build final JSON output using jq for proper escaping
jq -n \
    --arg status "conflicts_found" \
    --arg sha "$COMMIT_SHA" \
    --arg message "$COMMIT_MESSAGE" \
    --arg backup_dir "$BACKUP_DIR" \
    --argjson conflict_count "$CONFLICT_COUNT" \
    --argjson backed_up_count "$BACKUP_COUNT" \
    --argjson conflicts "$CONFLICTS_JSON" \
    --argjson exit_code 0 \
    '{
        status: $status,
        commit_sha: $sha,
        commit_message: $message,
        backup_dir: $backup_dir,
        conflict_count: $conflict_count,
        backed_up_count: $backed_up_count,
        conflicts: $conflicts,
        exit_code: $exit_code
    }'

exit 0

