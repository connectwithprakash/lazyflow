# Issue #168 — Feat: Add Morning Briefing prompt toggle

## Goal
Provide a Settings toggle for the Morning Briefing prompt and ensure TodayView respects it.

## Current Behavior
`TodayView` reads `@AppStorage("morningBriefingEnabled")` but:
- no Settings UI exists to control it
- `shouldShowMorningBriefingPrompt` does not check the value

## Desired Behavior
- Users can enable/disable the Morning Briefing prompt in Settings.
- Prompt appears only if enabled.

## Proposed Design
### Settings
- Add a toggle under the “Morning Briefing” settings section:
  - Label: "Show Morning Briefing Prompt"
  - `@AppStorage("morningBriefingEnabled")`
  - Default `true` or `false`? (Recommend `true` to encourage use, but verify current defaults)

### TodayView Prompt Logic
- Update `shouldShowMorningBriefingPrompt`:
  - `guard morningBriefingEnabled else { return false }`

## Implementation Steps
1. Add toggle UI in `SettingsView` near existing Morning Briefing notification section.
2. Wire to `@AppStorage("morningBriefingEnabled")`.
3. Update `TodayView.shouldShowMorningBriefingPrompt` to check the toggle.
4. Update UI tests to verify toggle behavior.

## Edge Cases
- If notifications are disabled, prompt toggle should still work independently.
- Respect existing last-viewed logic so prompt doesn’t reappear same day.

## Tests
- Add/extend `LazyflowUITests` to:
  - Turn off the toggle and verify prompt does not appear.
  - Turn on toggle and verify prompt appears in morning window with tasks.

## Files Likely Touched
- `Lazyflow/Sources/Views/SettingsView.swift`
- `Lazyflow/Sources/Views/TodayView.swift`
- `LazyflowUITests/LazyflowUITests.swift`
