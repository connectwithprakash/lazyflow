---
disable-model-invocation: true
argument-hint: "[issue-number]"
description: "End-to-end feature/bug implementation from GitHub issue to commit-ready code"
---

# Implement Feature/Fix

Orchestrates the full development workflow for a GitHub issue. Detects `bug` label to choose `fix/` vs `feat/` branch prefix.

## Phase 1: Research

1. Fetch the issue: `gh issue view $ARGUMENTS --json title,body,labels,milestone`
2. Determine branch prefix from labels: `bug` -> `fix/`, everything else -> `feat/`
3. Pull latest main: `git pull origin main`
4. Create branch: `git checkout -b {prefix}/$ARGUMENTS-{slug}`
5. Read the issue body thoroughly — extract acceptance criteria, edge cases, linked issues
6. Explore related code using Task(Explore) agents for broad searches, Grep/Glob for targeted lookups
7. Search the web for best practices given the tech stack (Swift, SwiftUI, Core Data, EventKit)

**Exit criteria:** You can describe the problem, affected files, and approach in 2-3 sentences.

## Phase 2: Plan

1. List all files to create/modify with a brief description of changes
2. Identify Core Data model changes (if any) — flag for manual user handling
3. Identify potential conflicts with in-progress work on other branches
4. Verify assumptions against existing code — read before modifying

**Exit criteria:** Implementation plan is concrete enough to write tests against.

## Phase 3: Implement (TDD)

1. Write failing unit tests first based on acceptance criteria
2. Implement the minimum code to make tests pass
3. Iterate: add edge case tests, make them pass
4. Run full test suite: `xcodebuild test -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:LazyflowTests/{TestClass}`
5. If new Swift files were added: `xcodegen generate` then rebuild
6. Create small, atomic commits: `feat($ARGUMENTS): description` or `fix($ARGUMENTS): description`

**Exit criteria:** All new and existing tests pass. Build succeeds.

## Phase 4: Verify

1. Build the full project: `xcodebuild build -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
2. Run the complete test suite (not just new tests)
3. Check for compiler warnings
4. Review your own diff: `git diff main...HEAD`

**Exit criteria:** Clean build, all tests pass, no warnings.

## Phase 5: Review

1. Invoke `/codex-peer-review` to run Codex peer review
2. Fix ALL issues found (critical, warning, AND nits) — re-run tests, re-verify
3. Continue review rounds until Codex returns zero findings and recommends "ship"
4. Update documentation if needed (auto-loads `updating-documentation` knowledge)

**Exit criteria:** Codex review recommends "ship" with zero unresolved issues. "ship-with-known-risks" is NOT acceptable — fix everything or justify to the user why a specific item cannot be fixed.

## Phase 6: Commit & Report

1. Ensure all changes are committed with conventional commit messages
2. Summarize what was done, what was tested, and any known limitations
3. Wait for user to approve PR creation (do NOT push without permission)
