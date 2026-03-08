---
disable-model-invocation: true
argument-hint: "[screen-name or 'full']"
description: "Performance profiling, benchmarks, and optimization recommendations"
---

# Performance Audit

Systematic performance analysis of the Lazyflow app. Targets a specific screen or performs a full audit.

## Phase 1: Scope

1. If specific screen: identify the View, ViewModel, and backing Services
2. If 'full': audit these critical paths:
   - App launch → TodayView render
   - Core Data fetch requests
   - Calendar sync (EventKit)
   - AI prioritization service
   - List scrolling performance
   - Sheet presentation/dismiss

## Phase 2: Static Analysis

### 2a. ViewModel Efficiency
- [ ] Check for unnecessary `@Published` updates (value unchanged but still published)
- [ ] Look for `objectWillChange.send()` called too frequently
- [ ] Verify expensive computations are cached, not recalculated on every access
- [ ] Check that `@MainActor` isn't used on CPU-intensive methods (should dispatch to background)

### 2b. Core Data Patterns
- [ ] Check for N+1 query patterns (fetching related objects in a loop)
- [ ] Verify `NSFetchRequest` uses `fetchBatchSize` for large result sets
- [ ] Check `relationshipKeyPathsForPrefetching` for relationship traversals
- [ ] Look for `NSManagedObjectContext.perform {}` vs main thread access
- [ ] Verify `NSFetchedResultsController` is used for list-backed views

### 2c. SwiftUI View Performance
- [ ] Check for expensive body computations (should be in ViewModel)
- [ ] Look for unnecessary `@ObservedObject` redraws (use `.equatable()` or break into subviews)
- [ ] Verify `List` uses `id:` parameter correctly for diffing
- [ ] Check for `ForEach` over large collections without `LazyVStack`
- [ ] Look for inline closures that create new objects on every render

### 2d. Memory & Threading
- [ ] Check for retain cycles in closures (missing `[weak self]`)
- [ ] Verify `Task` cancellation is handled (`.task { }` auto-cancels, manual Tasks need `checkCancellation()`)
- [ ] Check for leaked `AnyCancellable` subscriptions
- [ ] Look for images loaded without caching
- [ ] Verify background operations use appropriate QoS

### 2e. Network & Sync
- [ ] Check CloudKit sync frequency (not too aggressive)
- [ ] Verify EventKit access is batched, not per-event
- [ ] Check for redundant API calls (debouncing, caching)

## Phase 3: Write Performance Tests

### Performance Test Template

Provide a concrete `measure {}` test for the biggest bottleneck found. Always include data seeding, dependency injection, and the specific call being measured.

## Phase 4: Recommendations

Present findings in a structured table with columns: Finding | Severity (H/M/L) | Fix | Expected Impact.

Prioritize findings by impact:

### High Impact (fix immediately)
- Main thread blocking (any operation > 16ms)
- N+1 fetch patterns
- Retain cycles causing memory growth
- Missing fetchBatchSize on large fetches

### Medium Impact (fix soon)
- Unnecessary @Published updates
- Missing view extraction (large body computations)
- Redundant CloudKit syncs
- Images without caching

### Low Impact (nice to have)
- Minor allocation optimizations
- String interpolation in hot paths
- Enum over String for type comparisons

## Phase 5: Write Performance Tests

Always produce at least one `measure {}` block test for the primary bottleneck identified. Performance tests are essential because they give the developer a concrete before/after measurement — without them, the audit findings are just theory.

Use this XCTest performance test template adapted to the specific findings:

```swift
func test{ScreenName}LoadPerformance() throws {
    let persistenceController = PersistenceController(inMemory: true)
    // Seed realistic data volume (100+ tasks for TodayView, etc.)
    let context = persistenceController.container.viewContext
    for i in 0..<100 {
        let task = TaskItem(context: context)
        task.title = "Task \(i)"
        task.createdAt = Date()
        task.isCompleted = (i % 5 == 0)
    }
    try context.save()

    let viewModel = TodayViewModel(/* inject dependencies */)

    measure {
        viewModel.refreshTasks()
    }
}
```

### Baseline Targets
| Metric | Target | Critical |
|--------|--------|----------|
| ViewModel init | < 10ms | > 50ms |
| Task list fetch (100 items) | < 20ms | > 100ms |
| View body evaluation | < 5ms | > 16ms (drops frame) |
| Calendar sync | < 500ms | > 2s |
| App launch to interactive | < 1s | > 3s |

## Phase 6: Verify Fixes

```bash
# Run performance tests
xcodebuild test -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LazyflowTests/{PerformanceTestClass}
```

1. Compare before/after measure{} baselines
2. Check memory footprint hasn't increased
3. Verify no functional regressions with full test suite
4. Document improvements in commit message
