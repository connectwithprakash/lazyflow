#!/bin/bash
# PreToolUse hook: blocks writes to protected files
# Exit 0 = allow, Exit 2 = block with message

# This hook receives tool name and input via environment or stdin
# Parse the JSON input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only check Edit and Write tools
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
    exit 0
fi

# No file path means nothing to check
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Protected file patterns
PROTECTED_PATTERNS=(
    "*.xcdatamodeld*"
    "*.xcdatamodel*"
    ".env"
    ".env.*"
    "*.p8"
    "*.p12"
    "*.cer"
    "*.mobileprovision"
    "GoogleService-Info.plist"
    "fastlane/Appfile"
    "fastlane/Matchfile"
    "*.xcodeproj/project.pbxproj"
)

BASENAME=$(basename "$FILE_PATH")
RELPATH="${FILE_PATH#*/lazyflow/}"

for PATTERN in "${PROTECTED_PATTERNS[@]}"; do
    case "$RELPATH" in
        $PATTERN)
            echo "BLOCKED: $FILE_PATH is a protected file ($PATTERN). Edit manually or ask the user for explicit approval."
            exit 2
            ;;
    esac
    case "$BASENAME" in
        $PATTERN)
            echo "BLOCKED: $FILE_PATH is a protected file ($PATTERN). Edit manually or ask the user for explicit approval."
            exit 2
            ;;
    esac
done

exit 0
