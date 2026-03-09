#!/bin/bash
#
# Validate that release metadata files are updated for the target version.
# Prevents merging Release Please PRs with stale App Store / TestFlight notes.
#
# Usage: ./scripts/check-release-metadata.sh [version]
#   If version is omitted, reads from .release-please-manifest.json
#
# Exit codes:
#   0 — all metadata files reference the target version
#   1 — one or more files are stale or missing

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Resolve version
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    MANIFEST=".release-please-manifest.json"
    if [ ! -f "$MANIFEST" ]; then
        echo -e "${RED}Error: No version argument and $MANIFEST not found${NC}"
        exit 1
    fi
    VERSION=$(jq -r '."."' "$MANIFEST")
    if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
        echo -e "${RED}Error: Could not read version from $MANIFEST${NC}"
        exit 1
    fi
fi

# major.minor for flexible matching (e.g., "1.10" matches "v1.10" or "v1.10.0")
MAJOR_MINOR=$(echo "$VERSION" | cut -d. -f1,2)

echo "Checking release metadata for v${VERSION} (pattern: ${MAJOR_MINOR})"
echo ""

FAILED=0

check_file() {
    local file="$1"
    local label="$2"

    if [ ! -f "$file" ]; then
        echo -e "${RED}FAIL${NC} $label — file not found: $file"
        FAILED=1
        return
    fi

    if grep -q "$MAJOR_MINOR" "$file"; then
        echo -e "${GREEN}PASS${NC} $label references v${MAJOR_MINOR}"
    else
        echo -e "${RED}FAIL${NC} $label does not reference v${MAJOR_MINOR}"
        echo -e "${YELLOW}     Update $file before merging the release PR.${NC}"
        FAILED=1
    fi
}

check_file "fastlane/metadata/en-US/release_notes.txt"   "release_notes.txt"
check_file "fastlane/metadata/en-US/testflight_notes.txt" "testflight_notes.txt"

echo ""
if [ "$FAILED" -ne 0 ]; then
    echo -e "${RED}Release metadata is stale. Update the files above for v${VERSION} and push to the release branch.${NC}"
    exit 1
fi

echo -e "${GREEN}All release metadata is up to date for v${VERSION}.${NC}"
