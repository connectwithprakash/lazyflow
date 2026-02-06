# Issue #165 — Fix: Prevent preload from suppressing Daily Summary prompt

## Goal
Ensure `preloadInsightsData()` does not mark the Daily Summary as generated for today unless the user actually opens or explicitly generates the summary.

## Current Behavior (Problem)
`DailySummaryService.preloadInsightsData()` calls `generateSummary(for:)`, which:
- saves the summary to history
- updates `last_summary_date` (used by `hasTodaySummary`)
- updates streaks

This causes TodayView’s Daily Summary prompt to disappear before the user ever views it.

## Desired Behavior
- Preloading should create a preview that can populate UI fast, but **must not** update history, streaks, or `last_summary_date`.
- The summary should be persisted only when the user opens Daily Summary or explicitly triggers generation.

## Proposed Design
Add a preview mode to summary generation.

### Service Changes
- Add a new method in `DailySummaryService`:
  - `generateSummaryPreview(for:) -> DailySummaryData`
  - This should compute summary data and AI summary if available, but **not** call:
    - `saveSummary(...)`
    - `updateStreak(...)`
    - `todaySummary = ...` (optional: can update in-memory `todaySummary` with a flag)
- Alternatively: add a `persist` flag to `generateSummary(for: Date, persist: Bool)`.

### Preload Changes
- Update `preloadInsightsData()` to call **preview** method instead of `generateSummary()`.

### Prompt Visibility
- Confirm `TodayView.shouldShowSummaryPrompt` still checks `summaryService.hasTodaySummary`.
- Ensure `hasTodaySummary` reflects persisted state only (it already uses `last_summary_date`).

## Implementation Steps
1. Add preview generation method or `persist` flag in `DailySummaryService`.
2. Refactor `generateSummary(for:)` to call a shared internal builder method.
3. Update `preloadInsightsData()` to use preview path.
4. If needed, add a separate `todaySummaryPreview` property or reuse `todaySummary` but make sure it doesn’t set `last_summary_date`.
5. Confirm `DailySummaryView.loadSummary()` still triggers the persisted path.

## Edge Cases
- LLM unavailable: preview should still return valid summary data and encouragement.
- No completed tasks: preview should not crash; empty state should still show.
- Multiple preloads in same day should not change persisted summary state.

## Tests
Add/adjust unit tests in `LazyflowTests/DailySummaryServiceTests.swift`:
- Verify preview does **not** set `hasTodaySummary`.
- Verify persisted `generateSummary` **does** set `hasTodaySummary`.
- Verify `preloadInsightsData()` doesn’t suppress prompt (can be done by simulating preload then checking `hasTodaySummary`).

## Files Likely Touched
- `Lazyflow/Sources/Services/DailySummaryService.swift`
- `LazyflowTests/DailySummaryServiceTests.swift`
- `Lazyflow/Sources/Views/TodayView.swift` (verify behavior only, may not need changes)
