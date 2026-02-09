---
disable-model-invocation: true
description: "Iterative Codex MCP peer review loop (max 3 rounds)"
---

# Codex Peer Review

Runs an iterative peer review using Codex via MCP. Hard maximum: 3 rounds.

## Procedure

### Round 1: Initial Review

1. Gather the full diff:
   ```bash
   git diff main...HEAD
   ```
2. Send to Codex for review with context:
   ```
   Review this iOS/SwiftUI diff for: logic errors, edge cases, memory leaks,
   thread safety (@MainActor correctness), Core Data concurrency issues,
   SwiftUI view lifecycle bugs, accessibility gaps, and security concerns.
   Categorize each finding as: critical / warning / nit.
   ```
3. Parse Codex response — extract actionable items by severity

### Round 2-3: Fix & Re-verify

For each round (if issues remain):
1. Fix all critical and warning items
2. Rebuild and run tests
3. Send updated diff back to Codex:
   ```
   Here are the fixes for your review findings. Verify the fixes are correct
   and check for any new issues introduced. Previous findings: {summary}
   ```
4. If Codex confirms zero remaining criticals/warnings, exit early

### Exit

After round 3 (or early exit), output a summary:

```
## Peer Review Summary
- Rounds completed: {n}/3
- Critical issues: {resolved}/{total}
- Warnings: {resolved}/{total}
- Nits: {list of unresolved nits, if any}
- Recommendation: ship | ship-with-known-risks | hold
```

**ship** = zero unresolved issues of any severity (target outcome)
**ship-with-known-risks** = unresolved nits or minor warnings — NOT acceptable, fix them or escalate to user
**hold** = unresolved critical issues remain

**Goal: always reach "ship".** Fix all criticals, warnings, AND nits before concluding. If a nit truly cannot be fixed (out of scope, requires architectural change), explain why to the user and get explicit approval to skip it.

## When NOT to Use

- Trivial changes (typos, comment updates, version bumps)
- Changes the user has already reviewed themselves
- Pure documentation or metadata changes
