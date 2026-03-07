---
disable-model-invocation: true
argument-hint: "[record|update|verify] [TestClassName]"
description: "Record, update, and verify snapshot tests"
---

# Snapshot Testing Skill

Manage snapshot tests for the Lazyflow iOS app. Supports recording new snapshots, updating existing ones, and verifying current reference images.

## Execution Requirement

This skill requires EXECUTING commands, not just planning them. When asked to record, update, or verify snapshots:
1. Actually edit the test file (set isRecording = true/false)
2. Actually run xcodebuild test
3. Actually verify the results

Do not produce a plan describing what to do — perform the actions.

## Phase 1: Determine Action

Parse the argument to determine the operation:

- **`record [TestClassName]`** — Create and record a new snapshot test class
- **`update [TestClassName]`** — Re-record reference images for an existing test class
- **`verify [TestClassName]`** — Run snapshot tests without recording to check pass/fail
- If no `TestClassName` is given, operate on **all** snapshot tests in `LazyflowTests/Snapshots/`

## Phase 2: Record New Snapshots

Follow these steps when creating a new snapshot test:

### 1. Create the test class

Create a new file at `LazyflowTests/Snapshots/{TestClassName}.swift` extending `SnapshotTestCase`:

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import Lazyflow
import LazyflowCore

final class {TestClassName}: SnapshotTestCase {

    func testDefaultState() {
        let view = {ViewUnderTest}()
        assertLightAndDarkSnapshot(of: view, named: "default")
    }

    func testAccessibility() {
        let view = {ViewUnderTest}()
        assertAccessibilitySnapshot(of: view, named: "{viewName}")
    }
}
```

### 2. Use deterministic data

- Use `SnapshotFixtures` for all test data (dates, tasks, notes, drafts)
- Use `SnapshotFixtures.fixedNow` instead of `Date()` for deterministic output
- Create new fixture methods in `SnapshotFixtures.swift` if needed
- For views needing `FocusSessionCoordinator`, wrap with `wrapInEnvironment()` or `wrapInNavigation()`

### 3. Use the right assertion helpers

From `SnapshotTestCase`:

| Helper | Use For |
|--------|---------|
| `assertLightAndDarkSnapshot(of:named:)` | Light + dark mode pair |
| `assertAccessibilitySnapshot(of:named:)` | xxxLarge + accessibility3 Dynamic Type pair |
| `wrapInEnvironment(_:)` | Views needing `FocusSessionCoordinator` |
| `wrapInNavigation(_:)` | Views needing `NavigationStack` + `FocusSessionCoordinator` |

### 4. Record reference images

1. Set `isRecording = true` in the test's `setUp()`:
   ```swift
   override func setUp() {
       super.setUp()
       isRecording = true
   }
   ```
2. Run the tests:
   ```bash
   xcodebuild test -scheme Lazyflow \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -only-testing:LazyflowTests/Snapshots/{TestClassName}
   ```
3. Verify reference images exist in `LazyflowTests/Snapshots/__Snapshots__/{TestClassName}/`
4. Set `isRecording = false` (remove the override or comment out)
5. Re-run tests to confirm they pass

### 5. Finalize

- If a new `.swift` file was added: run `xcodegen generate`
- Commit reference images to git

## Phase 3: Update Existing Snapshots

When UI has changed and reference images need updating:

1. Identify which test class needs re-recording
2. Set `isRecording = true` in the test class `setUp()`:
   ```swift
   override func setUp() {
       super.setUp()
       isRecording = true
   }
   ```
3. Run the tests to re-record:
   ```bash
   xcodebuild test -scheme Lazyflow \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -only-testing:LazyflowTests/Snapshots/{TestClassName}
   ```
4. Set `isRecording = false` (remove the override or comment out)
5. Re-run tests to verify they pass
6. Review changed images with `git diff --stat` to confirm the right files changed

## Phase 4: Verify Current Snapshots

Run snapshot tests without recording to validate reference images:

```bash
# Verify a specific test class
xcodebuild test -scheme Lazyflow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LazyflowTests/Snapshots/{TestClassName}

# Verify ALL snapshot tests
xcodebuild test -scheme Lazyflow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LazyflowTests/Snapshots
```

For failures:
- Check if the UI intentionally changed — if so, use the **update** action to re-record
- Check if test data changed — ensure `SnapshotFixtures` values haven't drifted
- Check for environment differences — local vs CI rendering can differ

## Phase 5: CI Considerations

- **Record on CI**: Reference images should ideally be recorded on CI (macOS 15 runner) for cross-platform consistency. Local recordings may differ due to rendering differences.
- **Environment variable**: Set `SNAPSHOT_RECORD=true` as an env var to trigger recording on CI without code changes.
- **Tolerance**: Default precision `0.99`, perceptual precision `0.98` — allows minor anti-aliasing differences.
- **Viewport**: Fixed iPhone 13 Pro (375x812) regardless of simulator, ensuring consistent image sizes.
- **Simulator**: Tests run on iPhone 17 Pro locally but the viewport is locked to iPhone 13 Pro dimensions.

## Test Patterns

### Simple view (no dependencies)

```swift
final class MyViewSnapshotTests: SnapshotTestCase {

    func testDefaultState() {
        let view = MyView()
        assertLightAndDarkSnapshot(of: view, named: "default")
    }

    func testAccessibility() {
        let view = MyView()
        assertAccessibilitySnapshot(of: view, named: "myView")
    }
}
```

### View with ViewModel and mock service

```swift
final class MyViewSnapshotTests: SnapshotTestCase {

    func testEmptyState() {
        let view = wrapInEnvironment(
            MyView(taskService: SnapshotFixtures.emptyTaskService())
        )
        assertLightAndDarkSnapshot(of: view, named: "empty")
    }

    func testPopulatedState() {
        let view = wrapInEnvironment(
            MyView(taskService: SnapshotFixtures.populatedTaskService())
        )
        assertLightAndDarkSnapshot(of: view, named: "populated")
    }
}
```

### View with ViewModel state manipulation

```swift
final class MyViewSnapshotTests: SnapshotTestCase {

    func testLoadingState() {
        let vm = MyViewModel()
        vm.viewState = .loading
        let view = MyView(viewModel: vm)
        assertLightAndDarkSnapshot(of: view, named: "loading")
    }

    func testErrorState() {
        let vm = MyViewModel()
        vm.viewState = .error(message: "Something went wrong")
        let view = MyView(viewModel: vm)
        assertLightAndDarkSnapshot(of: view, named: "error")
    }
}
```

### View requiring UserDefaults stabilization

```swift
final class MyViewSnapshotTests: SnapshotTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(someValue, forKey: "someKey")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "someKey")
        super.tearDown()
    }
}
```

## Checklist

- [ ] Reference images committed to git (in `__Snapshots__/{TestClassName}/`)
- [ ] `isRecording` set to `false` in committed code
- [ ] Tests pass locally after recording
- [ ] `xcodegen generate` run if new `.swift` files were added
- [ ] Both light and dark mode snapshots included (`assertLightAndDarkSnapshot`)
- [ ] Accessibility snapshots included where appropriate (`assertAccessibilitySnapshot`)
- [ ] Deterministic data from `SnapshotFixtures` used (no `Date()` or random values)
