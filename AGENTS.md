# AGENTS.md

Lazyflow — AI-powered, calendar-integrated todo app for iOS.

## Tech Stack

- **Language:** Swift | **UI:** SwiftUI | **Data:** Core Data (offline-first)
- **Cloud:** CloudKit (iCloud sync) | **Calendar:** EventKit
- **AI:** Apple Intelligence (on-device) | **Target:** iOS 17.0+ (min 16.0)
- **Architecture:** MVVM + Combine | **Project:** XcodeGen (`project.yml`)

## Build & Test

```bash
# Build
xcodebuild build -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

# Test (specific class)
xcodebuild test -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:LazyflowTests/{TestClass}

# Test (all)
xcodebuild test -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

# After adding/removing Swift files
xcodegen generate
```

## Code Patterns

**ViewModels:** `@MainActor final class FooViewModel: ObservableObject` with `@Published` properties
**Services:** Singletons via `static let shared`, DI via init params for testing
**Sheet flows:** `NavigationStack` inside sheet, `.task { await loadData() }` for async loading
**State tracking:** `@AppStorage("lastXDate")` as `Double` (timeIntervalSince1970), check with `Calendar.current.isDateInToday()`
**Prompt cards:** Button with HStack (icon circle + VStack text + chevron), `.buttonStyle(.plain)`

## Common Pitfalls

- Swift `guard` body MUST exit (return/throw) — use `if` when else block conditionally continues
- TodayView List sections must ALWAYS be present (even when empty) — prevents UICollectionView section count mismatch crashes
- Never edit `.xcdatamodeld` files programmatically — Core Data model changes require manual handling
- XcodeGen: run `xcodegen generate` after adding/removing Swift files, or build will fail

## Git Conventions

- **Branches:** `feat/{issue}-{slug}` or `fix/{issue}-{slug}` (e.g., `feat/43-smart-learning`)
- **Commits:** `feat(scope): description`, `fix(scope):`, `test(scope):`, `chore:`
- **PRs:** Conventional commit title + `Closes #{issue}` in body

## Escalation Policy

Four levels of autonomy. When multiple levels apply, the **highest triggered level wins**.

### L0 — Autonomous (no confirmation needed)
- Read any file, search code, explore codebase
- Edit application source code (Swift, SwiftUI, tests)
- Run builds and tests
- Create branches, make commits
- Run `xcodegen generate`
- Update documentation files

### L1 — Inform (do it, then tell the user)
- Install/update Swift packages
- Modify `project.yml` (XcodeGen config)
- Modify CI workflow files (`.github/workflows/`)
- Update `Podfile`, `Gemfile`, or dependency configs

### L2 — Confirm (ask before doing)
- Modify Core Data models (`.xcdatamodeld`)
- Change deployment targets or build settings
- Modify signing, provisioning, or entitlements
- Delete files or branches
- Modify `.env`, certificates, or credentials

### L3 — User-initiated only (never do unless explicitly asked)
- `git push` to remote
- Create or merge pull requests
- Deploy to TestFlight or App Store
- Modify `fastlane/Appfile` or `fastlane/Matchfile`
- Force push, reset --hard, or other destructive git operations

## Release Workflow

Milestone-based release lifecycle with Release Please:

```
Issues in milestone (e.g., v1.8)
  → Feature branches per issue → PRs merged to main
    → Release Please auto-creates/updates release PR
      → Developer merges Release Please PR (decision point 1)
        → CI: GitHub Release + tag + version bump + TestFlight build
          → Developer updates promotional_text.txt (decision point 2)
            → Developer triggers App Store workflow (decision point 3)
```

Three human decisions in the entire pipeline. Everything else is automated.

## Multi-Agent Setup

**Primary agent:** Claude Code — development, testing, documentation
**Peer reviewer:** OpenAI Codex via MCP (`codex` server, `gpt-5.3-codex`, high reasoning)

**Use Codex for:** Post-implementation review, architecture decisions, complex logic validation, pre-PR review
**Skip Codex for:** Trivial changes, user-reviewed code, exploratory research

## Error Recovery

When blocked:
1. Re-read error messages carefully — most failures have clear causes
2. Check if `xcodegen generate` is needed (missing file references)
3. Check if simulator is booted: `xcrun simctl list devices | grep Booted`
4. Clean build folder: `xcodebuild clean -scheme Lazyflow`
5. If still stuck, explain the problem and ask the user

## Quality Standards

- Production-ready code only — no temporary solutions or hardcoded values
- TDD: write tests first, then implement to make them pass
- Verify all user flows end-to-end
- Validate edge cases and error states
- Use subagents (Task tool) for parallel exploration and complex research

## References

- Architecture: `docs/project/architecture.md`
- Design System: `docs/project/design-system.md`
- User Flows: `docs/project/user-flows.md`
- Roadmap: `docs/project/roadmap.md`
- Deployment: `docs/project/deployment.md`
