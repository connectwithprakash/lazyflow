# Issue #163 — Feat: Track AI impressions for Morning Briefing + Daily Summary

## Goal
Record AI impressions when AI content is displayed in Morning Briefing or Daily Summary, so correction/refinement metrics are complete.

## Current Behavior
`AILearningService.recordImpression()` is called only in `AddTaskView` when AI suggestions are shown.

## Desired Behavior
- Record an impression when AI text is actually visible in the briefing/summary UI.
- Avoid double-counting on refresh or repeated view load.

## Proposed Design
### Impression Trigger
- When `aiSummary` (or equivalent AI content) is **first shown** in a view session, record an impression.
- If user taps “Regenerate”, record another impression only when the new AI content is displayed.

### Implementation Strategy
- Add local state in `MorningBriefingView` and `DailySummaryView`:
  - `@State private var didRecordImpression = false`
- When content is loaded and `aiSummary` is non-nil and `didRecordImpression == false`, call:
  - `AILearningService.shared.recordImpression()`
  - set `didRecordImpression = true`
- On regenerate, reset the flag so the new AI output counts as a fresh impression.

## Implementation Steps
1. Add `didRecordImpression` state in both views.
2. Hook into `loadSummary()` / `loadBriefing()` completion to record impressions when AI is present.
3. If “Regenerate” is implemented (Issue #164), reset `didRecordImpression` before reloading.

## Edge Cases
- If AI is unavailable and only default encouragement is shown, do **not** record an impression.
- If AI content appears later (after loading), ensure the impression triggers once.

## Tests
- Unit tests for view logic are hard; consider testing at service level or add UI tests:
  - Verify impression count increases when AI summary is displayed.

## Files Likely Touched
- `Lazyflow/Sources/Views/MorningBriefingView.swift`
- `Lazyflow/Sources/Views/DailySummaryView.swift`
- `Lazyflow/Sources/Services/AI/AILearningService.swift` (no change expected)
- `LazyflowUITests/LazyflowUITests.swift` (optional)
