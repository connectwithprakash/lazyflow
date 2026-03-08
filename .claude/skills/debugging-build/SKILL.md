---
disable-model-invocation: true
argument-hint: "[error-context e.g. 'build failed' or 'test TestClass failed']"
description: "Systematic build and test failure debugging"
---

# Debug Build/Test Failure

Systematic approach to diagnosing and fixing build or test failures. Argument can be an error message, 'build', or 'test'.

## Phase 1: Capture & Categorize

1. If no error context provided, run the failing command:
   ```bash
   # Build
   xcodebuild build -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -50
   # Tests
   xcodebuild test -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -80
   ```

2. Categorize the failure:
   - **Compilation error** — syntax, type mismatch, missing import
   - **Linker error** — undefined symbol, duplicate symbol
   - **Module not found** — SPM package issue, missing framework
   - **File not found** — XcodeGen out of sync
   - **Signing error** — provisioning, entitlements
   - **Simulator error** — not booted, runtime missing
   - **Test assertion failure** — logic bug, snapshot mismatch
   - **Test crash** — EXC_BAD_ACCESS, nil unwrap, section count mismatch

## Phase 2: Apply Targeted Fix

### File not found / Missing reference
```bash
xcodegen generate
xcodebuild build -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

### Module not found (LazyflowCore, LazyflowUI, SnapshotTesting)
```bash
# Resolve SPM packages
xcodebuild -resolvePackageDependencies -scheme Lazyflow
# If persists, clean and rebuild
xcodebuild clean -scheme Lazyflow
xcodebuild build -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

### Simulator not booted
```bash
xcrun simctl boot "iPhone 17 Pro"
# Verify
xcrun simctl list devices | grep "iPhone 17 Pro"
```

### Simulator runtime missing
```bash
# List available runtimes
xcrun simctl list runtimes
# If iOS runtime missing, install via Xcode > Settings > Platforms
```

### Signing / Provisioning error
- This is an L2 issue — inform the user
- Check: `CODE_SIGNING_ALLOWED=NO` for simulator builds
- For device builds: `bundle exec fastlane sync_dev_certs`

### Test assertion failure
1. Read the failing test to understand expected behavior
2. Read the implementation code being tested
3. Identify the mismatch — is the test wrong or the implementation?
4. Fix the root cause (prefer fixing implementation unless test expectations are outdated)

### Snapshot test failure
1. Check if UI intentionally changed → re-record:
   ```bash
   # Set isRecording = true in the test, then:
   xcodebuild test -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -only-testing:LazyflowTests/Snapshots/{TestClass}
   ```
2. Check simulator/OS version mismatch (reference images recorded on CI macos-15)
3. Set isRecording = false and re-run to verify

### Core Data model mismatch
1. Check if `.xcdatamodeld` was modified without creating a new version
2. Verify `NSPersistentContainer` model version matches
3. For tests: ensure `PersistenceController` uses in-memory store

### UICollectionView section count crash (TodayView)
This is a **known pitfall** documented in CLAUDE.md. The fix is always the same:
- TodayView List sections must ALWAYS be present, even when empty
- Find the `if` or `guard` that conditionally removes a `Section` from the List body
- Replace conditional section removal with conditional content: keep the `Section` but put the content inside the `if`
- Example: `Section { if hasData { ForEach(items) { ... } } }` — the Section is always present, only the content is conditional
- This is caused by SwiftUI's List using UICollectionView internally, which crashes when section count changes mid-update

## Phase 3: Clean Build (if targeted fix didn't work)

```bash
# 1. Clean build folder
xcodebuild clean -scheme Lazyflow

# 2. Remove DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/Lazyflow-*

# 3. Regenerate project
xcodegen generate

# 4. Resolve packages fresh
xcodebuild -resolvePackageDependencies -scheme Lazyflow

# 5. Rebuild
xcodebuild build -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

## Phase 4: Escalation

If still failing after clean build:
1. Search for the exact error message in the codebase and online
2. Check if the issue is environment-specific (Xcode version, macOS version)
3. Check recent commits for breaking changes: `git log --oneline -10`
4. If the error is non-obvious, explain the problem to the user with:
   - Exact error message
   - Steps already tried
   - Suspected root cause
   - Proposed fix (if any)

## Quick Reference

| Symptom | First Try | Second Try |
|---------|-----------|------------|
| "No such module" | `xcodebuild -resolvePackageDependencies` | Clean + rebuild |
| "No such file" | `xcodegen generate` | Check file exists on disk |
| "Simulator not available" | `xcrun simctl boot "iPhone 17 Pro"` | Check `xcrun simctl list` |
| Test timeout | Check for `await` without timeout | Check for deadlock on @MainActor |
| EXC_BAD_ACCESS | Check force unwraps, check Core Data threading | Run with Address Sanitizer |
| Linker: duplicate symbol | Check SPM package imports | Clean DerivedData |
