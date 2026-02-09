#!/bin/bash
# archive.sh - Archive Claude Code session transcript and subagent logs

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_DIR="${PROJECT_DIR%/}"  # Strip trailing slash

# Archive destination - configurable via env var or argument
# Can be overridden with CLAUDE_ARCHIVE_DIR env var or --output=<path> argument
DEFAULT_ARCHIVE_BASE="${PROJECT_DIR}/docs/process/claudeCodeSessions"
ARCHIVE_BASE="${CLAUDE_ARCHIVE_DIR:-${DEFAULT_ARCHIVE_BASE}}"

# Claude Code stores transcripts in ~/.claude/projects/<project-hash>/
# The hash is the project's native OS path with path separators and : replaced by -.
#
# Cross-platform issue: on Windows, MSYS/Git Bash pwd returns /d/code/project
# but Claude Code hashes the Windows-native path D:\code\project, producing
# D--code-project (: -> - and \ -> -). We must convert the MSYS path back to
# Windows-native format before hashing.
#
# See llamacpp/tools/scripts/bash-vars.just for the canonical cross-platform
# path strategy (pure string ops, no cygpath dependency).
compute_project_hash() {
    local dir="$1"

    # Detect MSYS/Git Bash path: /d/code/... where d is a drive letter
    if [[ "$dir" =~ ^/([a-zA-Z])(/|$) ]]; then
        local drive
        drive=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')
        dir="${drive}:${dir:2}"
        # /d/code/project -> D:/code/project
    fi

    # Replace : and / with - (matches Claude Code's project hash)
    echo "$dir" | sed 's|[:/\\]|-|g'
}

PROJECT_HASH=$(compute_project_hash "${PROJECT_DIR}")
TRANSCRIPT_DIR="${HOME}/.claude/projects/${PROJECT_HASH}"

# Accept session ID as first positional arg, or detect from most recent
# Supports: UUID, relative refs (last, last-1, HEAD, HEAD~1, etc.)
SESSION_REF=""
for arg in "$@"; do
    case "$arg" in
        --output=*) ARCHIVE_BASE="${arg#*=}" ;;
        *) [ -z "$SESSION_REF" ] && SESSION_REF="$arg" ;;
    esac
done

# Resolve relative session references to UUID
# Supports: last, last-N (N = 0-based offset from most recent)
resolve_session_ref() {
    local ref="$1"
    local offset=0

    case "$ref" in
        # last = most recent (offset 0)
        last)
            offset=0
            ;;
        # last-N = Nth before most recent
        last-[0-9]*)
            offset="${ref#last-}"
            ;;
        # Already a UUID - return as-is
        *)
            echo "$ref"
            return 0
            ;;
    esac

    # Get session at offset (1-indexed for sed, so offset+1)
    local line_num=$((offset + 1))
    local session_file
    session_file=$(ls -t "${TRANSCRIPT_DIR}"/*.jsonl 2>/dev/null | sed -n "${line_num}p" || true)

    if [ -z "$session_file" ]; then
        echo "Error: No session found at offset ${offset}" >&2
        return 1
    fi

    basename "$session_file" .jsonl
}

SESSION_ID=""
if [ -n "${SESSION_REF}" ]; then
    SESSION_ID=$(resolve_session_ref "${SESSION_REF}") || exit 1
fi

# Security: Validate SESSION_ID format (UUID only)
if [ -n "${SESSION_ID}" ]; then
    if ! [[ "${SESSION_ID}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
        echo "Error: Invalid session ID format. Expected UUID format (e.g., 602fca42-0159-466c-bdb7-00745e1939f1)"
        exit 1
    fi
fi

# Security: Validate and normalize ARCHIVE_BASE path

# Safe tilde expansion (no eval — eval allows arbitrary command injection)
if [[ "${ARCHIVE_BASE}" == "~" ]]; then
    ARCHIVE_BASE="${HOME}"
elif [[ "${ARCHIVE_BASE}" == "~/"* ]]; then
    ARCHIVE_BASE="${HOME}/${ARCHIVE_BASE#\~/}"
fi

# Normalize to absolute path (resolves symlinks and ..)
ARCHIVE_BASE=$(cd "$(dirname "${ARCHIVE_BASE}")" 2>/dev/null && pwd)/$(basename "${ARCHIVE_BASE}") || {
    echo "Error: Invalid output path: ${ARCHIVE_BASE}"
    exit 1
}

# Security: Block sensitive system directories.
# Checked AFTER normalization so symlinks and .. are already resolved.
case "${ARCHIVE_BASE}" in
    /etc | /etc/* | /bin | /bin/* | /sbin | /sbin/* | \
    /usr/bin | /usr/bin/* | /usr/sbin | /usr/sbin/* | \
    /System | /System/* | /private/etc | /private/etc/* | \
    /private/var/root | /private/var/root/* | \
    /c/[Ww]indows | /c/[Ww]indows/* | C:/[Ww]indows | C:/[Ww]indows/*)
        echo "Error: Cannot archive to system directory: ${ARCHIVE_BASE}"
        exit 1
        ;;
esac

if [ -z "${SESSION_ID}" ]; then
    # Find most recently modified .jsonl file = current session
    LATEST_TRANSCRIPT=$(ls -t "${TRANSCRIPT_DIR}"/*.jsonl 2>/dev/null | head -1 || true)
    if [ -n "${LATEST_TRANSCRIPT}" ]; then
        SESSION_ID=$(basename "${LATEST_TRANSCRIPT}" .jsonl)

        # Validate auto-detected session ID
        if ! [[ "${SESSION_ID}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
            echo "Error: Auto-detected invalid session ID format"
            exit 1
        fi

        echo "Detected current session: ${SESSION_ID}"
    fi
fi

if [ -z "${SESSION_ID}" ]; then
    echo "No session found to archive"
    exit 0
fi

# Verify session exists
MAIN_TRANSCRIPT="${TRANSCRIPT_DIR}/${SESSION_ID}.jsonl"
if [ ! -f "${MAIN_TRANSCRIPT}" ]; then
    echo "Session transcript not found: ${MAIN_TRANSCRIPT}"
    exit 1
fi

# Archive destination with export timestamp
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
SESSION_ARCHIVE="${ARCHIVE_BASE}/exported-on-${TIMESTAMP}"

mkdir -p "${SESSION_ARCHIVE}"

# Archive main transcript
echo "Archiving main transcript..."
cp "${MAIN_TRANSCRIPT}" "${SESSION_ARCHIVE}/session.jsonl"
MAIN_SIZE=$(ls -lh "${SESSION_ARCHIVE}/session.jsonl" | awk '{print $5}')
echo "Main transcript: ${MAIN_SIZE}"

# Archive subagent logs if they exist
SUBAGENTS_DIR="${TRANSCRIPT_DIR}/${SESSION_ID}/subagents"
SUBAGENT_COUNT=0
if [ -d "${SUBAGENTS_DIR}" ]; then
    SUBAGENT_COUNT=$(find "${SUBAGENTS_DIR}" -name "agent-*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
    if [ "${SUBAGENT_COUNT}" -gt 0 ]; then
        echo "Archiving ${SUBAGENT_COUNT} subagent transcripts..."
        cp -rL "${SUBAGENTS_DIR}" "${SESSION_ARCHIVE}/subagents"
    fi
fi

# Generate HTML and Markdown reports with claude-code-log
generate_report() {
    local source="$1"
    local label="$2"
    local format="$3"
    local format_upper
    format_upper=$(echo "$format" | tr '[:lower:]' '[:upper:]')  # portable (bash 3.2/macOS)
    local open_flag=""

    # Only open browser for HTML, not for MD
    [ "$format" = "html" ] && open_flag="--open-browser"

    if command -v claude-code-log &>/dev/null; then
        echo "Generating ${label} ${format_upper} report..."
        claude-code-log "${source}" -f "${format}" ${open_flag} 2>/dev/null || {
            echo "Warning: ${label} ${format_upper} report generation failed"
        }
    elif command -v uvx &>/dev/null; then
        echo "Generating ${label} ${format_upper} report via uvx..."
        uvx claude-code-log@latest "${source}" -f "${format}" ${open_flag} 2>/dev/null || {
            echo "Warning: ${label} ${format_upper} report generation failed"
        }
    else
        echo "Warning: claude-code-log not available, skipping ${label} ${format_upper} report"
    fi
}

# Generate main session HTML and Markdown
if [ -f "${SESSION_ARCHIVE}/session.jsonl" ]; then
    generate_report "${SESSION_ARCHIVE}/session.jsonl" "main session" "html"
    generate_report "${SESSION_ARCHIVE}/session.jsonl" "main session" "md"
fi

# Generate individual HTML and MD per subagent file
if [ "${SUBAGENT_COUNT}" -gt 0 ]; then
    for agent_file in "${SESSION_ARCHIVE}/subagents"/agent-*.jsonl; do
        [ -f "$agent_file" ] || continue
        agent_name=$(basename "$agent_file" .jsonl)

        generate_report "$agent_file" "${agent_name}" "html"
        generate_report "$agent_file" "${agent_name}" "md"
    done
fi

# Create session metadata
cat >"${SESSION_ARCHIVE}/session-info.txt" <<EOF
Session ID: ${SESSION_ID}
Project: ${PROJECT_DIR}
Timestamp: ${TIMESTAMP}
Main Transcript: ${MAIN_SIZE}
Subagent Count: ${SUBAGENT_COUNT}
Formats: HTML, Markdown
EOF

echo ""
echo "Session archive complete: ${SESSION_ARCHIVE}"
cat "${SESSION_ARCHIVE}/session-info.txt"
