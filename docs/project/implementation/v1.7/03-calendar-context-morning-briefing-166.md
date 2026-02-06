# Issue #166 — Feat: Add calendar context to Morning Briefing

## Goal
Include today’s calendar context in Morning Briefing: total meeting time, next event, and largest free block.

## Current Behavior
Morning Briefing only uses tasks. Calendar events are ignored.

## Desired Behavior
- If calendar access is granted:
  - Show meeting totals and next upcoming event.
  - Show largest free block for today.
  - Include these stats in AI prompt to make the briefing more actionable.
- If access is denied: briefing remains task-only.

## Proposed Design
### Data Model
Extend `MorningBriefingData` with optional calendar summary:
- `calendarTotalMeetingMinutes: Int`
- `calendarNextEvent: CalendarEventSummary?`
- `calendarLargestFreeBlockMinutes: Int`

Create a lightweight summary model to avoid leaking EventKit types into views:
```
struct CalendarEventSummary: Codable {
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
}
```

### Calendar Stats Algorithm
1. Fetch today’s events via `CalendarService.fetchEvents(from:to:)`.
2. Filter out all-day events for meeting totals and free-block calculation (show all-day separately if desired).
3. Meeting minutes = sum of (end - start) for non-all-day events.
4. Next event = first event with startDate >= now (or first today if all in past).
5. Largest free block = max gap between:
   - start of day and first event
   - end of event i and start of event i+1
   - end of last event and end of workday (consider optional workday range, e.g., 8–18)

### UI
Add a “Today’s Schedule” card in `MorningBriefingView` with:
- Total meeting time (e.g., “2h 30m in meetings”)
- Next event (title + time)
- Largest free block (e.g., “Longest free block: 1h 45m”)

### AI Prompt
Append schedule stats to the briefing prompt when data is available.

## Implementation Steps
1. Add calendar summary fields to `MorningBriefingData`.
2. Add helper in `DailySummaryService` to compute schedule summary.
3. Update `generateMorningBriefingInternal()` to populate calendar summary when access granted.
4. Update `MorningBriefingView` to render the new schedule card if data exists.
5. Update `buildMorningBriefingPrompt()` to include schedule stats (guarded).

## Edge Cases
- No calendar access: skip schedule section.
- No events today: show “No meetings today” (optional) and treat free block as whole day/workday.
- Overlapping events: ensure free block calculation uses merged intervals.

## Tests
- Add unit tests for schedule calculations (empty events, overlapping events, all-day events).
- Ensure briefing generation still works without calendar access.

## Files Likely Touched
- `Lazyflow/Sources/Models/DailySummaryData.swift`
- `Lazyflow/Sources/Services/DailySummaryService.swift`
- `Lazyflow/Sources/Services/CalendarService.swift` (if helper needed)
- `Lazyflow/Sources/Views/MorningBriefingView.swift`
- `LazyflowTests/DailySummaryServiceTests.swift`
