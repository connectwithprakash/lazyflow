#!/bin/bash
# bump-version.sh - Update version numbers across the project
#
# Usage: ./scripts/bump-version.sh <version>
# Example: ./scripts/bump-version.sh 1.2.0

set -e

VERSION="$1"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.2.0"
    exit 1
fi

# Validate version format (x.y.z)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format x.y.z (e.g., 1.2.0)"
    exit 1
fi

# Cross-platform sed in-place edit
sed_inplace() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

echo "Bumping version to $VERSION..."

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Update Xcode project
echo "  - Updating project.pbxproj"
sed_inplace "s/MARKETING_VERSION = [0-9]*\.[0-9]*\.[0-9]*/MARKETING_VERSION = $VERSION/g" Lazyflow.xcodeproj/project.pbxproj

# Update XcodeGen source of truth
if [ -f "project.yml" ]; then
    echo "  - Updating project.yml"
    sed_inplace "s/MARKETING_VERSION: [0-9]*\.[0-9]*\.[0-9]*/MARKETING_VERSION: $VERSION/g" project.yml
fi

# Update website version badge
echo "  - Updating docs/site/index.html"
sed_inplace "s/<span class=\"version\">v[0-9]*\.[0-9]*\.[0-9]*</<span class=\"version\">v$VERSION</g" docs/site/index.html

# Update design system version
if [ -f "docs/site/design/index.html" ]; then
    echo "  - Updating docs/site/design/index.html"
    sed_inplace "s/Design System v[0-9]*\.[0-9]*\.[0-9]*/Design System v$VERSION/g" docs/site/design/index.html
fi

# Update README version badge
echo "  - Updating README.md"
sed_inplace "s/badge\/version-[0-9]*\.[0-9]*\.[0-9]*/badge\/version-$VERSION/g" README.md

echo "Done! Version updated to $VERSION"
