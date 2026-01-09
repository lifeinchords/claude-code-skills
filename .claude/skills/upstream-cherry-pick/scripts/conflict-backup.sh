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

COMMIT_SHA="${1:-unknown}"
COMMIT_MESSAGE="${2:-}"

# Verify we're in a git repo
if ! git rev-parse --git-dir &>/dev/null; then
    echo '{"status": "error", "message": "Not a git repository", "exit_code": 2}'
    exit 2
fi

# Get conflicted files
CONFLICTED_FILES=$(git diff --name-only --diff-filter=U 2>/dev/null || true)

if [[ -z "$CONFLICTED_FILES" ]]; then
    echo '{"status": "no_conflicts", "message": "No merge conflicts detected", "exit_code": 1}'
    exit 1
fi

# Create dated backup directory
BACKUP_DATE=$(date +%Y-%m-%d)
BACKUP_DIR="temp/merge-backups/$BACKUP_DATE"

if ! mkdir -p "$BACKUP_DIR"; then
    echo '{"status": "error", "message": "Failed to create backup directory", "backup_dir": "'"$BACKUP_DIR"'", "exit_code": 3}'
    exit 3
fi

# Initialize JSON output
CONFLICTS_JSON="["
FIRST=true
BACKUP_COUNT=0
BACKUP_FAILED=()

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    
    # Create parent directory in backup location
    FILE_DIR=$(dirname "$file")
    mkdir -p "$BACKUP_DIR/$FILE_DIR" 2>/dev/null || true
    
    # Copy file to backup
    BACKED_UP=false
    if cp "$file" "$BACKUP_DIR/$file" 2>/dev/null; then
        BACKED_UP=true
        ((BACKUP_COUNT++))
    else
        BACKUP_FAILED+=("$file")
    fi
    
    # Find conflict line numbers (where <<<<<<< HEAD appears)
    CONFLICT_LINES=$(grep -n "<<<<<<< HEAD" "$file" 2>/dev/null | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
    [[ -z "$CONFLICT_LINES" ]] && CONFLICT_LINES="unknown"
    
    # Determine conflict type by analyzing the file
    CONFLICT_TYPE="MODIFICATION"  # default
    
    # Check if file exists in HEAD
    if ! git show HEAD:"$file" &>/dev/null; then
        CONFLICT_TYPE="ADDITION"
    else
        # Check if incoming side deleted the file
        # (conflict markers present but file was deleted on one side)
        if grep -q "<<<<<<< HEAD" "$file" && grep -q ">>>>>>>" "$file"; then
            # Check the content between markers
            HEAD_CONTENT=$(sed -n '/<<<<<<< HEAD/,/=======/p' "$file" 2>/dev/null | grep -v "<<<<<<< HEAD" | grep -v "=======" || true)
            INCOMING_CONTENT=$(sed -n '/=======/,/>>>>>>>/p' "$file" 2>/dev/null | grep -v "=======" | grep -v ">>>>>>>" || true)
            
            if [[ -z "$HEAD_CONTENT" ]]; then
                CONFLICT_TYPE="DELETION"  # HEAD side is empty
            elif [[ -z "$INCOMING_CONTENT" ]]; then
                CONFLICT_TYPE="DELETION"  # Incoming side is empty
            fi
        fi
    fi
    
    # Escape file path for JSON
    FILE_ESCAPED=$(echo "$file" | sed 's/"/\\"/g')
    
    # Build JSON object for this conflict
    if [[ "$FIRST" == "true" ]]; then
        FIRST=false
    else
        CONFLICTS_JSON+=","
    fi
    
    CONFLICTS_JSON+='
    {
      "file": "'"$FILE_ESCAPED"'",
      "lines": ['"$CONFLICT_LINES"'],
      "type": "'"$CONFLICT_TYPE"'",
      "backed_up": '"$BACKED_UP"'
    }'
    
done <<< "$CONFLICTED_FILES"

CONFLICTS_JSON+="
  ]"

# Count total conflicts
CONFLICT_COUNT=$(echo "$CONFLICTED_FILES" | wc -l | tr -d ' ')

# Escape commit message for JSON
COMMIT_MESSAGE_ESCAPED=$(echo "$COMMIT_MESSAGE" | sed 's/"/\\"/g' | sed "s/'/\\'/g")

# Build final JSON output
cat <<EOF
{
  "status": "conflicts_found",
  "commit_sha": "$COMMIT_SHA",
  "commit_message": "$COMMIT_MESSAGE_ESCAPED",
  "backup_dir": "$BACKUP_DIR",
  "conflict_count": $CONFLICT_COUNT,
  "backed_up_count": $BACKUP_COUNT,
  "conflicts": $CONFLICTS_JSON,
  "exit_code": 0
}
EOF

exit 0

