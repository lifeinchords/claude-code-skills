#!/usr/bin/env bash
#
# check-deps.sh
# Checks if required dependencies (git, gh, jq) are installed
# Offers to install via brew if missing
#
# Platform: macOS only (uses brew for package management)
# TODO: Add Windows (winget/choco) and Linux (apt/dnf/pacman) support
#
# Usage: ./check-deps.sh
# Exit codes:
#   0 - All dependencies available
#   1 - Missing dependencies, user declined install
#   2 - Installation failed
#   3 - Unsupported operating system
#
# Output: JSON with status details

set -euo pipefail
IFS=$'\n\t'

# Error trap for debugging
trap 'echo "Error in check-deps.sh at line $LINENO" >&2' ERR

REQUIRED_DEPS=("git" "gh" "jq")

# JSON string escape function (can't use jq yet - it might be missing!)
# Pure bash implementation - no external dependencies
# Escapes quotes, backslashes, and control characters for JSON
json_escape() {
    local input="$1"
    local output=""
    local char

    for ((i=0; i<${#input}; i++)); do
        char="${input:$i:1}"
        case "$char" in
            '"')  output+='\"' ;;
            '\\') output+='\\\\' ;;
            $'\n') output+='\n' ;;
            $'\r') output+='\r' ;;
            $'\t') output+='\t' ;;
            $'\b') output+='\b' ;;
            $'\f') output+='\f' ;;
            *)    output+="$char" ;;
        esac
    done

    printf '%s' "$output"
}

# Check operating system
if [[ "$(uname -s)" != "Darwin" ]]; then
    OS_NAME=$(json_escape "$(uname -s)")
    echo '{"status": "error", "message": "Unsupported operating system. This skill currently only supports macOS.", "os": "'"$OS_NAME"'", "required_deps": ["git", "gh", "jq"]}'
    exit 3
fi

MISSING_DEPS=()

# Check git
if ! command -v git &>/dev/null; then
    MISSING_DEPS+=("git")
fi

# Check gh CLI
if ! command -v gh &>/dev/null; then
    MISSING_DEPS+=("gh")
fi

# Check jq
if ! command -v jq &>/dev/null; then
    MISSING_DEPS+=("jq")
fi

# All deps present - NOW we can use jq safely (if it's installed)!
if [[ ${#MISSING_DEPS[@]} -eq 0 ]]; then
    jq -n '{"status": "ok", "message": "All dependencies installed", "git": true, "gh": true, "jq": true}'
    exit 0
fi

# Build missing list for JSON (without using jq - it might be missing!)
MISSING_JSON="["
FIRST_DEP=true
for dep in "${MISSING_DEPS[@]}"; do
    if [[ "$FIRST_DEP" == "true" ]]; then
        FIRST_DEP=false
    else
        MISSING_JSON+=","
    fi
    MISSING_JSON+="\"$dep\""
done
MISSING_JSON+="]"

# Check if brew is available
if ! command -v brew &>/dev/null; then
    DEPS_LIST=$(json_escape "${MISSING_DEPS[*]}")
    echo '{"status": "error", "message": "brew not found. Please install missing dependencies manually: '"$DEPS_LIST"'"}'
    exit 1
fi

# Prompt for installation
echo '{"status": "missing", "missing": '"$MISSING_JSON"', "message": "Some dependencies are not installed"}' >&2
printf '\nMissing dependencies: %s\n\n' "${MISSING_DEPS[*]}" >&2
printf 'Install missing dependencies via brew? [y/N] ' >&2
read -r -n 1 REPLY
printf '\n' >&2

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo '{"status": "declined", "message": "User declined installation", "missing": '"$MISSING_JSON"'}'
    exit 1
fi

# Install missing deps
printf 'Installing: %s...\n' "${MISSING_DEPS[*]}" >&2
for dep in "${MISSING_DEPS[@]}"; do
    printf '  -> brew install %s\n' "$dep" >&2
    if ! brew install "$dep"; then
        # If jq was just installed, we can use it now; otherwise use json_escape
        if command -v jq &>/dev/null; then
            jq -n \
                --arg dep "$dep" \
                --argjson missing "$MISSING_JSON" \
                '{"status": "error", "message": ("Failed to install " + $dep), "missing": $missing, "failed": $dep}'
        else
            DEP_ESCAPED=$(json_escape "$dep")
            echo '{"status": "error", "message": "Failed to install '"$DEP_ESCAPED"'", "missing": '"$MISSING_JSON"', "failed": "'"$DEP_ESCAPED"'"}'
        fi
        exit 2
    fi
done

printf '\n' >&2
# Now jq should be available after installation
if command -v jq &>/dev/null; then
    jq -n --argjson installed "$MISSING_JSON" '{"status": "ok", "message": "Dependencies installed successfully", "installed": $installed}'
else
    echo '{"status": "ok", "message": "Dependencies installed successfully", "installed": '"$MISSING_JSON"'}'
fi
exit 0

