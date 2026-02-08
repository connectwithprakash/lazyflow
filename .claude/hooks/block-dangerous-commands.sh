#!/bin/bash
# PreToolUse hook: blocks dangerous shell commands
# Exit 0 = allow, Exit 2 = block with message

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only check Bash tool
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Dangerous command patterns
DANGEROUS_PATTERNS=(
    "git push --force"
    "git push -f "
    "git push -f$"
    "git reset --hard"
    "git checkout -- ."
    "git clean -f"
    "rm -rf /"
    "rm -rf ~"
    "rm -rf \$HOME"
    "fastlane release"
    "fastlane submit"
    "drop table"
    "DROP TABLE"
    "--no-verify"
    "gh pr merge"
)

for PATTERN in "${DANGEROUS_PATTERNS[@]}"; do
    if [[ "$COMMAND" == *"$PATTERN"* ]]; then
        echo "BLOCKED: Command contains dangerous pattern '$PATTERN'. Ask the user for explicit approval before running this command."
        exit 2
    fi
done

exit 0
