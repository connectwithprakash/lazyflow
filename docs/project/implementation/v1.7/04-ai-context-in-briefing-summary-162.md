# Issue #162 — Feat: Inject AI learning context into Morning Briefing + Daily Summary prompts

## Goal
Use v1.6 AI learning context (patterns + corrections + duration accuracy) when generating Morning Briefing and Daily Summary AI content.

## Current Behavior
Both prompts are built only from task stats; they do not include `AIContextService` output.

## Desired Behavior
Prompts include the AI context string when available, improving personalization.

## Proposed Design
### Prompt Integration
- Use `AIContextService.shared.buildContextString()` as an additional prompt section.
- Keep prompt size bounded (truncate context to a safe limit if needed).
- If context is empty, omit the section.

### Placement
- Daily Summary: add “User Preferences” block after stats.
- Morning Briefing: add “User Preferences” block after Today’s Plan.

### Size Control
Implement a small helper to clamp context length (e.g., 1,000–1,500 chars) to avoid oversized prompts.

## Implementation Steps
1. Add a helper in `DailySummaryService`:
   - `private func clampedAIContext() -> String`
2. In `buildSummaryPrompt(...)`, append context block if non-empty.
3. In `buildMorningBriefingPrompt(...)`, append context block if non-empty.
4. Ensure the AI context string is safe for prompts (no empty/placeholder text).

## Edge Cases
- `AIContextService` returns “No user preferences learned yet.” — treat as empty.
- LLM not available: prompts should not be used but context calculation should not crash.

## Tests
- Update `DailySummaryServiceTests` to validate prompt contains context when present.
- Add a test to ensure empty context does not add a “User Preferences” section.

## Files Likely Touched
- `Lazyflow/Sources/Services/DailySummaryService.swift`
- `Lazyflow/Sources/Services/AI/AIContextService.swift` (optional helper)
- `LazyflowTests/DailySummaryServiceTests.swift`
