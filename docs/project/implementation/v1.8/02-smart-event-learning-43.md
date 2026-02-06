# Smart Learning for Event-to-Task Preferences (#43)

## Overview

Learn from user behavior to improve the "Plan Your Day" experience. Over time, the app understands which calendar events the user typically converts to tasks and which they skip.

## Problem

Users have recurring events they never convert to tasks (1:1 meetings, team standups, lunch blocks). These appear every day in the selection screen, adding noise and friction to the planning flow.

## Solution

Track user patterns and use them to:
1. De-emphasize events the user typically skips
2. Optionally auto-hide frequently skipped event types
3. Pre-sort events by likelihood of selection

## Dependencies

- #41 - Plan Your Day (primary flow this enhances)

## Data Model

### EventSelectionHistory

```swift
struct EventSelectionHistory: Codable {
    let id: UUID
    let eventPattern: EventPattern
    var selectedCount: Int
    var skippedCount: Int
    var lastSeen: Date

    var selectionRate: Double {
        guard (selectedCount + skippedCount) > 0 else { return 0.5 }
        return Double(selectedCount) / Double(selectedCount + skippedCount)
    }

    var isFrequentlySkipped: Bool {
        (selectedCount + skippedCount) >= 3 && selectionRate < 0.2
    }
}

struct EventPattern: Codable, Hashable {
    let titleKeywords: Set<String>
    let calendarId: String?
    let isRecurring: Bool
}
```

### EventLearningService

```swift
final class EventLearningService: ObservableObject {
    static let shared = EventLearningService()

    func recordSelection(event: CalendarEventSummary, wasSelected: Bool)
    func selectionLikelihood(for event: CalendarEventSummary) -> Double
    func shouldAutoHide(_ event: CalendarEventSummary) -> Bool
    func sortedByLikelihood(_ events: [CalendarEventSummary]) -> [CalendarEventSummary]
    func resetLearning()
}
```

## UI Integration

### Visual De-emphasis

Events frequently skipped shown with:
- Lighter text color (0.5 opacity)
- Moved to bottom of list
- Optional "Usually skipped" label

### Auto-hide Setting

```swift
Toggle("Hide events I usually skip", isOn: $autoHideSkippedEvents)
```

When enabled:
- Frequently skipped events hidden by default
- "Show N hidden events" link to reveal them

## Privacy Considerations

- All learning happens on-device
- No event titles stored verbatim (only keyword patterns)
- User can reset learning anytime in Settings

## Acceptance Criteria

- [ ] Track which events user selects/skips in Plan Your Day
- [ ] After 3+ occurrences, calculate selection likelihood
- [ ] De-emphasize frequently skipped events (opacity, sort order)
- [ ] Setting to auto-hide frequently skipped events
- [ ] "Show hidden" option to reveal auto-hidden events
- [ ] Reset learning option in Settings
