#!/bin/bash
#
# Generate user-friendly App Store release notes from CHANGELOG.md
# Transforms technical changelog into benefit-focused release notes
#
# Usage: ./scripts/generate-release-notes.sh <version>
# Example: ./scripts/generate-release-notes.sh 1.7.0

set -e

VERSION="${1:-}"
CHANGELOG_FILE="CHANGELOG.md"
OUTPUT_FILE="fastlane/metadata/en-US/release_notes.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Version argument required${NC}"
    echo "Usage: $0 <version>"
    echo "Example: $0 1.7.0"
    exit 1
fi

if [ ! -f "$CHANGELOG_FILE" ]; then
    echo -e "${RED}Error: $CHANGELOG_FILE not found${NC}"
    exit 1
fi

# Extract the section for this version from CHANGELOG.md
CHANGELOG_SECTION=$(awk "/^## \[$VERSION\]/{flag=1; next} /^## \[/{flag=0} flag" "$CHANGELOG_FILE")

if [ -z "$CHANGELOG_SECTION" ]; then
    echo -e "${RED}Error: Version $VERSION not found in $CHANGELOG_FILE${NC}"
    exit 1
fi

# Extract features and clean up commit message format
extract_features() {
    echo "$CHANGELOG_SECTION" | \
        awk '/^### Features/{flag=1; next} /^### /{flag=0} flag' | \
        grep "^\* " | \
        sed 's/^\* \*\*[^:]*:\*\* //' | \
        sed 's/^\* //' | \
        sed 's/ (\[.*$//' | \
        sed 's/ \[#[0-9]*\].*$//'
}

# Extract bug fixes
extract_bugs() {
    echo "$CHANGELOG_SECTION" | \
        awk '/^### Bug Fixes/{flag=1; next} /^### /{flag=0} flag' | \
        grep "^\* " | \
        sed 's/^\* \*\*[^:]*:\*\* //' | \
        sed 's/^\* //' | \
        sed 's/ (\[.*$//' | \
        sed 's/ \[#[0-9]*\].*$//'
}

# Count features and bugs
FEATURE_COUNT=$(extract_features | wc -l | tr -d ' ')
BUG_COUNT=$(extract_bugs | wc -l | tr -d ' ')

# Determine the headline based on features
FEATURES=$(extract_features)
HEADLINE=""

# Try to identify headline feature (first feature or one with key words)
if echo "$FEATURES" | grep -qi "morning briefing\|plan your day"; then
    HEADLINE="Plan Your Day"
elif echo "$FEATURES" | grep -qi "calendar"; then
    HEADLINE="Calendar Integration"
elif echo "$FEATURES" | grep -qi "ai\|intelligence"; then
    HEADLINE="Smarter AI"
elif echo "$FEATURES" | grep -qi "widget\|watch"; then
    HEADLINE="New Ways to Access"
elif echo "$FEATURES" | grep -qi "category\|organization"; then
    HEADLINE="Better Organization"
elif echo "$FEATURES" | grep -qi "recurring\|habit"; then
    HEADLINE="Recurring & Habits"
else
    # Default: use first feature as headline
    HEADLINE=$(echo "$FEATURES" | head -1 | cut -c1-30)
fi

# Generate user-friendly release notes
{
    # Headline
    echo "$HEADLINE"

    # Features as benefit-focused bullets
    if [ "$FEATURE_COUNT" -gt 0 ]; then
        echo "$FEATURES" | while read -r feature; do
            # Skip empty lines
            [ -z "$feature" ] && continue
            # Clean up and format
            echo "• $feature"
        done
    fi

    # Bug fixes section (only if there are bugs)
    if [ "$BUG_COUNT" -gt 0 ]; then
        echo ""
        if [ "$BUG_COUNT" -gt 2 ]; then
            echo "Bug Fixes"
            echo "• Various bug fixes and stability improvements"
        else
            echo "Bug Fixes"
            extract_bugs | while read -r bug; do
                [ -z "$bug" ] && continue
                echo "• $bug"
            done
        fi
    fi

} > "$OUTPUT_FILE"

# Remove any trailing empty lines
sed -i '' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$OUTPUT_FILE" 2>/dev/null || true

echo -e "${GREEN}Generated release notes for v$VERSION:${NC}"
echo "----------------------------------------"
cat "$OUTPUT_FILE"
echo "----------------------------------------"
echo -e "${GREEN}Saved to: $OUTPUT_FILE${NC}"
