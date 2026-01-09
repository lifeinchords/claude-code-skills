#!/usr/bin/env bash
#
# classify-commits.sh
# Analyzes commits and classifies as generic vs project-specific
#
# Platform: macOS only
# TODO: Add Windows and Linux cross-environment compatibility
#
# Usage: ./classify-commits.sh <remote/branch> [count]
# Example: ./classify-commits.sh tmp-project/main 10
#
# Output: JSON array with classification for each commit
#
# Classification rules:
#   GENERIC patterns (cherry-pickable agentic dev tooling and processes):
#     - .claude/agents/*, .claude/skills/*, .claude/hooks/*, .claude/prompts/*
#     - .cursor/rules/* (AI rules, NOT general IDE settings)
#     - .mcp.json, .cursor/mcp.json (MCP server configs)
#     - docs/process/*
#     - tools/*, scripts/*
#     - CLAUDE.md
#     - Commit message starts with [process]
#
#   PROJECT-SPECIFIC patterns (auto-skip):
#     - *.workspace files
#     - docs/prd/*
#     - src/*, app/*, pages/* (feature code)
#     - .env* files
#     - IDE editor preferences (.vscode/settings.json, .idea/)
#     - Commit message starts with [projectname]
#
#   NEEDS REVIEW (Claude inspects diff):
#     - package.json: SKIP if changing project name/config, but KEEP if adding
#       agentic packages like @anthropic-ai/claude-code, @modelcontextprotocol/*
#     - Mixed commits touching both generic and project-specific paths

set -euo pipefail

REMOTE_BRANCH="${1:-}"
COUNT="${2:-10}"

if [[ -z "$REMOTE_BRANCH" ]]; then
    echo '{"error": "No remote/branch provided. Usage: classify-commits.sh <remote/branch> [count]"}'
    exit 1
fi

# Verify the remote branch exists
if ! git rev-parse --verify "$REMOTE_BRANCH" &>/dev/null; then
    echo '{"error": "Remote branch not found", "branch": "'"$REMOTE_BRANCH"'"}'
    exit 1
fi

# Generic path patterns (agentic dev tooling that's typically reusable)
GENERIC_PATTERNS=(
    "^\.claude/agents/"
    "^\.claude/skills/"
    "^\.claude/hooks/"
    "^\.claude/prompts/"
    "^\.claude/CLAUDE\.md$"
    "^CLAUDE\.md$"
    "^\.cursor/rules/"
    "^\.mcp\.json$"
    "^\.cursor/mcp\.json$"
    "^docs/process/"
    "^tools/agents"
    "^scripts/context-search/"
)

# Project-specific path patterns (auto-skip, no review needed)
PROJECT_PATTERNS=(
    "^src/"
    "^app/"
    "^pages/"
    "^components/"
    "^docs/prd"
    "^\.env"
    "\.workspace$"
    "^\.vscode/settings\.json$"
    "^\.cursor/settings\.json$"
    "^\.idea/"
)

# Files that need Claude's judgment (inspect the actual diff)
# package.json: could be project config OR adding agentic deps
# These are NOT in PROJECT_PATTERNS so they fall through to needs_review
NEEDS_REVIEW_NOTE="package.json, package-lock.json - check if adding agentic packages"

# Start JSON output
echo '['

FIRST=true
while IFS= read -r line; do
    SHA=$(echo "$line" | cut -d' ' -f1)
    MESSAGE=$(echo "$line" | cut -d' ' -f2-)

    # Get files changed in this commit
    FILES=$(git diff-tree --no-commit-id --name-only -r "$SHA" 2>/dev/null | tr '\n' '|')
    FILES="${FILES%|}"  # Remove trailing pipe

    # Determine classification
    CLASSIFICATION="unknown"
    REASON=""

    # Check commit message prefix first
    if [[ "$MESSAGE" =~ ^\[process\] ]]; then
        CLASSIFICATION="generic"
        REASON="commit_message_prefix"
    elif [[ "$MESSAGE" =~ ^\[[a-zA-Z0-9_-]+\] ]] && [[ ! "$MESSAGE" =~ ^\[process\] ]]; then
        # Has a prefix that's not [process] - likely project-specific
        CLASSIFICATION="project_specific"
        REASON="commit_message_prefix"
    else
        # Analyze files
        GENERIC_COUNT=0
        PROJECT_COUNT=0

        IFS='|' read -ra FILE_ARRAY <<< "$FILES"
        for file in "${FILE_ARRAY[@]}"; do
            [[ -z "$file" ]] && continue

            # Check generic patterns
            for pattern in "${GENERIC_PATTERNS[@]}"; do
                if [[ "$file" =~ $pattern ]]; then
                    ((GENERIC_COUNT++))
                    break
                fi
            done

            # Check project patterns
            for pattern in "${PROJECT_PATTERNS[@]}"; do
                if [[ "$file" =~ $pattern ]]; then
                    ((PROJECT_COUNT++))
                    break
                fi
            done
        done

        if [[ $GENERIC_COUNT -gt 0 && $PROJECT_COUNT -eq 0 ]]; then
            CLASSIFICATION="generic"
            REASON="file_paths"
        elif [[ $PROJECT_COUNT -gt 0 ]]; then
            CLASSIFICATION="project_specific"
            REASON="file_paths"
        else
            CLASSIFICATION="needs_review"
            REASON="unclear_classification"
        fi
    fi

    # Escape message for JSON
    MESSAGE_ESCAPED=$(echo "$MESSAGE" | sed 's/"/\\"/g' | sed "s/'/\\'/g")
    FILES_ESCAPED=$(echo "$FILES" | sed 's/"/\\"/g')

    # Output JSON object
    if [[ "$FIRST" == "true" ]]; then
        FIRST=false
    else
        echo ","
    fi

    echo '  {'
    echo '    "sha": "'"$SHA"'",'
    echo '    "message": "'"$MESSAGE_ESCAPED"'",'
    echo '    "classification": "'"$CLASSIFICATION"'",'
    echo '    "reason": "'"$REASON"'",'
    echo '    "files": "'"$FILES_ESCAPED"'"'
    echo -n '  }'

done < <(git log "$REMOTE_BRANCH" --oneline -"$COUNT" --reverse)

echo ''
echo ']'
