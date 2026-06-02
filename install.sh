#!/usr/bin/env bash
# ecs install script - one command to install embedded-code-skill
set -euo pipefail

SKILL_DIR="${HOME}/.codex/skills/embedded-code-skill"
REPO_URL="https://raw.githubusercontent.com/leon-2050/embedded-code-skill/main"

echo "Installing embedded-code-skill to ${SKILL_DIR}..."

mkdir -p "${SKILL_DIR}"

# Download single-entry SKILL.md (show HTTP errors with -S)
if ! curl -Sf "${REPO_URL}/SKILL.md" -o "${SKILL_DIR}/SKILL.md"; then
    echo "Error: Failed to download SKILL.md from ${REPO_URL}" >&2
    echo "Check your network connection and ensure the repository URL is correct." >&2
    exit 1
fi

if [ ! -s "${SKILL_DIR}/SKILL.md" ]; then
    echo "Error: Downloaded SKILL.md is empty" >&2
    exit 1
fi

echo "Done! The skill is installed at ${SKILL_DIR}/SKILL.md"
echo "Usage: /ecs <command> [args]"
echo "  /ecs rewrite   - Clean up legacy code"
echo "  /ecs review    - Review for risks"
