---
user-invocable: false
description: "XcodeGen project sync knowledge auto-loaded when adding/removing Swift files"
---

# XcodeGen Sync

Auto-loaded when Swift files are added or removed. The project uses `project.yml` (XcodeGen) instead of manually editing `.xcodeproj`.

## When to Regenerate

Run `xcodegen generate` after:
- Adding new `.swift` files
- Removing `.swift` files
- Changing file group structure
- Modifying build settings or dependencies

## Command

```bash
xcodegen generate
```

## Post-Regeneration

1. Verify the build still succeeds:
   ```bash
   xcodebuild build -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
   ```
2. Do NOT commit `*.xcodeproj/project.pbxproj` changes separately — include them in the same commit as the source file changes

## Common Issues

- **New file not found in build:** Forgot to run `xcodegen generate`
- **Duplicate file reference:** File exists in `project.yml` glob pattern and was also added explicitly
- **Missing test target:** Ensure test files are in a directory covered by the test target glob in `project.yml`
