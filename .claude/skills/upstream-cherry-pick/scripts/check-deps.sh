#!/usr/bin/env bash
#
# check-deps.sh
# Checks if required dependencies (gh, jq) are installed
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

REQUIRED_DEPS=("gh" "jq")

# Check operating system
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo '{"status": "error", "message": "Unsupported operating system. This skill currently only supports macOS.", "os": "'"$(uname -s)"'", "required_deps": ["gh", "jq"]}'
    exit 3
fi

MISSING_DEPS=()

# Check gh CLI
if ! command -v gh &>/dev/null; then
    MISSING_DEPS+=("gh")
fi

# Check jq
if ! command -v jq &>/dev/null; then
    MISSING_DEPS+=("jq")
fi

# All deps present
if [[ ${#MISSING_DEPS[@]} -eq 0 ]]; then
    echo '{"status": "ok", "message": "All dependencies installed", "gh": true, "jq": true}'
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

echo '{"status": "missing", "missing": '"$MISSING_JSON"', "message": "Some dependencies are not installed"}'

# Check if brew is available
if ! command -v brew &>/dev/null; then
    echo '{"status": "error", "message": "brew not found. Please install missing dependencies manually: '"${MISSING_DEPS[*]}"'"}'
    exit 1
fi

# Prompt for installation
echo ""
echo "Missing dependencies: ${MISSING_DEPS[*]}"
echo ""
read -p "Install missing dependencies via brew? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo '{"status": "declined", "message": "User declined installation", "missing": '"$MISSING_JSON"'}'
    exit 1
fi

# Install missing deps
echo "Installing: ${MISSING_DEPS[*]}..."
for dep in "${MISSING_DEPS[@]}"; do
    echo "  -> brew install $dep"
    if ! brew install "$dep"; then
        echo '{"status": "error", "message": "Failed to install '"$dep"'", "missing": '"$MISSING_JSON"', "failed": "'"$dep"'"}'
        exit 2
    fi
done

echo ""
echo '{"status": "ok", "message": "Dependencies installed successfully", "installed": '"$MISSING_JSON"'}'
exit 0

