# Issue #167 — Feat: Handle Morning Briefing + Daily Summary notification actions

## Goal
Handle notification actions so tapping “View Summary” or “Start My Day” deep links to the correct screen.

## Current Behavior
Notification categories and actions are registered in `NotificationService`, but there’s no action handling or routing to the corresponding views.

## Desired Behavior
- Tapping notification actions navigates to:
  - Daily Summary view
  - Morning Briefing view
- Works from cold start, background, and foreground.

## Proposed Design
### Deep Link Routing
Add URL-based routing (or centralized app router):
- URL scheme (e.g., `lazyflow://daily-summary`, `lazyflow://morning-briefing`)
- Handle in app root view with `onOpenURL`.

### Notification Delegate
Implement `UNUserNotificationCenterDelegate` to capture action identifiers:
- `VIEW_SUMMARY_ACTION` -> open daily summary deep link
- `VIEW_BRIEFING_ACTION` -> open morning briefing deep link

### UI Entry
- Route into the current navigation stack or present a sheet.
- Respect iPad split view structure.

## Implementation Steps
1. Add a deep link router helper (if not already present).
2. Register `UNUserNotificationCenterDelegate` in app lifecycle.
3. On action, trigger the deep link.
4. Update root view to present `DailySummaryView` or `MorningBriefingView` when deep link is received.
5. Add UI tests (or manual verification) for action handling.

## Edge Cases
- If deep link arrives while another sheet is open, dismiss and present the target.
- If user disabled Morning Briefing prompt, deep links should still work.
- If LLM is unavailable, views should still open with fallback content.

## Tests
- Manual validation: send test notification, tap action, verify correct view.
- UI tests if feasible (may require test notification injection).

## Files Likely Touched
- `Lazyflow/Sources/Services/NotificationService.swift`
- App entry point (e.g., `LazyflowApp.swift` or root view)
- `Lazyflow/Sources/Views/TodayView.swift` or routing coordinator (if used)
- `LazyflowUITests/LazyflowUITests.swift` (optional)
