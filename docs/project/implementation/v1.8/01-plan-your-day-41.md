# Plan Your Day - Morning Planning Flow (#41)

## Overview

A morning planning ritual that helps users bridge their calendar and task list. Users review today's calendar events and select which ones to add as tasks, all in under 30 seconds.

## Problem

Calendars mix actionable items (prepare presentation, review PR) with non-actionable events (1:1 meeting, lunch, commute). Users need a way to extract the "work" from their schedule without manually creating tasks one by one.

## Solution

A "Plan Your Day" flow in the Today view that allows users to quickly select calendar events and convert them to tasks in bulk.

## User Flow

```
1. User opens app in morning
2. Sees "Plan Your Day" card in Today view
3. Taps card → Event selection screen
4. Taps to select actionable events
5. Taps "Start My Day" → Tasks created
6. Sees completion confirmation
```

## UI Components

### 1. Plan Your Day Card (Today View)

```
┌─────────────────────────────────────┐
│  ☀️  Plan Your Day                  │
│  You have 6 events today            │
│                        [Let's go →] │
└─────────────────────────────────────┘
```

**Display conditions:**
- User has calendar events for today
- Events haven't been reviewed yet today
- Morning Briefing is enabled (respects #168 toggle)

### 2. Event Selection Screen

```swift
struct PlanYourDayView: View {
    @StateObject private var viewModel: PlanYourDayViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.todayEvents) { event in
                    EventSelectionRow(
                        event: event,
                        isSelected: viewModel.selectedEvents.contains(event.id),
                        onToggle: { viewModel.toggleSelection(event) }
                    )
                }
            }
            .navigationTitle("Plan Your Day")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { viewModel.skip() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start My Day") { viewModel.createTasks() }
                        .disabled(viewModel.selectedEvents.isEmpty)
                }
            }
        }
    }
}
```

### 3. Completion Screen

```
┌─────────────────────────────────────┐
│           ✓ Day Planned             │
│                                     │
│   4 tasks created                   │
│   ~3 hours of focused work          │
│                                     │
│          [View My Day]              │
└─────────────────────────────────────┘
```

## Smart Defaults for Created Tasks

| Event Property | Task Property |
|---------------|---------------|
| Title | Title (unchanged) |
| Start time | Due time |
| Date | Due date |
| Duration | Estimated duration |
| - | Priority: Medium |
| - | Category: Work (default) |

## Persistence

Track "reviewed" state per day in UserDefaults:
```swift
"plan_your_day_YYYY-MM-DD" -> Bool
```

## Dependencies

- CalendarService (existing)
- TaskService (existing)
- Morning Briefing toggle (#168)

## Acceptance Criteria

- [ ] "Plan Your Day" card appears in Today view when user has calendar events
- [ ] Card does not appear if no events or already planned today
- [ ] Event selection screen shows all today's timed events
- [ ] User can select/deselect multiple events
- [ ] "Start My Day" creates tasks for all selected events
- [ ] "Skip" dismisses flow without creating tasks
- [ ] Completion screen shows summary with task count
- [ ] Created tasks appear in Today view with correct properties
