---
disable-model-invocation: true
description: "Local TestFlight deployment (escape hatch, not the standard CI path)"
---

# Deploy to TestFlight (Local)

This is the **manual escape hatch** for deploying to TestFlight from a local machine. The standard path is merging a Release Please PR, which triggers automatic CI deployment.

## Pre-deployment Checklist

1. Verify you're on the correct branch (usually `main` after Release Please merge)
2. All tests pass:
   ```bash
   xcodebuild test -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
   ```
3. Check release notes are updated: `fastlane/metadata/en-US/release_notes.txt`
4. Verify version numbers are correct: `scripts/bump-version.sh` was run

## Deploy

```bash
export MATCH_PASSWORD="<ask user>"
bundle exec fastlane beta
```

## Post-deployment

1. Verify the build appears in App Store Connect / TestFlight
2. Check build processing status
3. Notify user when build is available for testing

## When to Use

- CI pipeline is broken and a build is urgently needed
- Testing a specific branch build before merging
- User explicitly requests a local deploy
