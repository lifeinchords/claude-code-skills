#!/bin/bash

# pre-compact-archive.sh - PreCompact hook to archive session before context compaction
#
# Triggered automatically when Claude Code is about to compact context.
# Archives the full session transcript + subagent logs via archive-session skill.
#
# Hook input (JSON via stdin):
#   { "transcript_path": "~/.claude/projects/.../session.jsonl", "session_id": "uuid" }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
ARCHIVE_SCRIPT="${PROJECT_DIR}/.claude/skills/archive-session/scripts/archive.sh"

# Read hook input from stdin
INPUT=$(cat)

# Extract session_id from JSON input
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if [ -z "$SESSION_ID" ]; then
    echo "[pre-compact-archive] No session_id in hook input, skipping"
    exit 0
fi

if [ ! -f "$ARCHIVE_SCRIPT" ]; then
    echo "[pre-compact-archive] Archive script not found: $ARCHIVE_SCRIPT"
    exit 1
fi

echo "[pre-compact-archive] Archiving session before compact: $SESSION_ID"

# Pass session ID and any additional args to archive script
bash "$ARCHIVE_SCRIPT" "$SESSION_ID" "$@"

echo "[pre-compact-archive] Archive complete"
exit 0
