#!/bin/bash
#
# Generate App Store release notes from CHANGELOG.md
# Uses Release Please / Keep a Changelog format
#
# Usage: ./scripts/generate-release-notes.sh <version>
# Example: ./scripts/generate-release-notes.sh 1.3.0

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
    echo "Example: $0 1.3.0"
    exit 1
fi

if [ ! -f "$CHANGELOG_FILE" ]; then
    echo -e "${RED}Error: $CHANGELOG_FILE not found${NC}"
    exit 1
fi

# Extract the section for this version from CHANGELOG.md
# Gets content between ## [VERSION] and the next ## [
CHANGELOG_SECTION=$(awk "/^## \[$VERSION\]/{flag=1; next} /^## \[/{flag=0} flag" "$CHANGELOG_FILE")

if [ -z "$CHANGELOG_SECTION" ]; then
    echo -e "${RED}Error: Version $VERSION not found in $CHANGELOG_FILE${NC}"
    exit 1
fi

# Function to extract and format a section
extract_section() {
    local section_pattern="$1"
    local prefix="$2"

    echo "$CHANGELOG_SECTION" | awk "/^### $section_pattern/{flag=1; next} /^### /{flag=0} flag" | \
        grep "^\* " | \
        sed 's/^\* \*\*[^:]*:\*\* /'"$prefix"'/' | \
        sed 's/^\* /'"$prefix"'/' | \
        sed 's/ (\[.*$//g'
}

# Generate release notes (modern format - clean bullets, no prefixes)
{
    echo "What's New in $VERSION:"
    echo ""

    # Breaking Changes - keep ⚠️ prefix for visibility
    if echo "$CHANGELOG_SECTION" | grep -q "BREAKING CHANGES"; then
        extract_section ".*BREAKING CHANGES" "• ⚠️ "
    fi

    # Features (from feat: commits)
    if echo "$CHANGELOG_SECTION" | grep -q "### Features"; then
        extract_section "Features" "• "
    fi

    # Performance Improvements (from perf: commits)
    if echo "$CHANGELOG_SECTION" | grep -q "### Performance"; then
        extract_section "Performance.*" "• "
    fi

    # Bug Fixes - consolidate into single line if multiple
    if echo "$CHANGELOG_SECTION" | grep -q "### Bug Fixes"; then
        BUG_COUNT=$(echo "$CHANGELOG_SECTION" | awk '/^### Bug Fixes/{flag=1; next} /^### /{flag=0} flag' | grep -c "^\* " || true)
        if [ "$BUG_COUNT" -gt 2 ]; then
            echo "• Bug fixes and stability improvements"
        else
            extract_section "Bug Fixes" "• "
        fi
    fi

} > "$OUTPUT_FILE"

echo -e "${GREEN}Generated release notes for v$VERSION:${NC}"
echo "----------------------------------------"
cat "$OUTPUT_FILE"
echo "----------------------------------------"
echo -e "${GREEN}Saved to: $OUTPUT_FILE${NC}"
