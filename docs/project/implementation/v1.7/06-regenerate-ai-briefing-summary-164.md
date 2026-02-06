# Issue #164 — Feat: Add Regenerate AI actions for Morning Briefing + Daily Summary

## Goal
Allow users to explicitly regenerate AI content in Morning Briefing and Daily Summary, and track refinement requests.

## Current Behavior
The refresh button reloads data but does not explicitly re-run AI with a refinement signal.

## Desired Behavior
- Provide a “Regenerate” action that:
  - triggers AI generation again
  - updates the UI with new AI output
  - records `AILearningService.recordRefinementRequest()`

## Proposed Design
### Service API
Add explicit regenerate methods in `DailySummaryService`:
- `regenerateDailySummaryAI(for date: Date) -> DailySummaryData`
- `regenerateMorningBriefingAI() -> MorningBriefingData`

These should:
- reuse existing data (task summaries + stats)
- re-run AI prompt generation only
- preserve non-AI fields
- not reset streak/history unless a full persist is intended

### UI
- Add a “Regenerate” button near the AI section or in the toolbar:
  - Morning Briefing: near greeting card or toolbar menu
  - Daily Summary: near AI Summary card or toolbar menu
- Disable while generating.

### Analytics
- Call `AILearningService.shared.recordRefinementRequest()` when regenerate is tapped.

## Implementation Steps
1. Add regenerate methods to `DailySummaryService`.
2. Update `MorningBriefingView` to call regenerate and refresh state.
3. Update `DailySummaryView` to call regenerate and refresh state.
4. Record refinement requests on action.
5. Ensure impressions are re-recorded only when new AI output is shown (Issue #163).

## Edge Cases
- LLM unavailable: show fallback message and avoid crash.
- Rapid taps: disable button while `isGeneratingSummary` is true.
- Cached data: regenerating should not rebuild the whole summary history unless required.

## Tests
- Add/adjust tests to ensure regenerate returns updated AI fields.
- Verify refinement requests increment after regenerate calls.

## Files Likely Touched
- `Lazyflow/Sources/Services/DailySummaryService.swift`
- `Lazyflow/Sources/Views/MorningBriefingView.swift`
- `Lazyflow/Sources/Views/DailySummaryView.swift`
- `LazyflowTests/DailySummaryServiceTests.swift`
