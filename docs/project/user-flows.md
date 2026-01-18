# Lazyflow User Flows

Documentation of core user journeys, interaction patterns, and UX decisions.

> **Visual References**: Screenshots demonstrating these user flows are stored in `docs/site/assets/screenshots/` directory.

## Table of Contents

1. [Information Architecture](#information-architecture)
2. [Core User Flows](#core-user-flows)
3. [Empty States](#empty-states)
4. [Error States](#error-states)
5. [Gesture Interactions](#gesture-interactions)
6. [Navigation Patterns](#navigation-patterns)
7. [Accessibility](#accessibility)
8. [Performance Requirements](#performance-requirements)

---

## Information Architecture

### App Structure

```
Lazyflow
|-- Today (default landing)
|   |-- Overdue Tasks (red indicator)
|   |-- Today's Tasks (by priority)
|   |-- Completed Today (collapsible)
|   +-- Add Task (FAB)
|
|-- Calendar (v0.2.0+)
|   |-- Month View (overview)
|   |-- Week View (planning)
|   +-- Day View (time blocking)
|
|-- Upcoming
|   |-- Tomorrow
|   |-- This Week
|   +-- Later (grouped by date)
|
|-- Lists
|   |-- Inbox (default, cannot delete)
|   |-- Custom Lists (user-created)
|   +-- Add List
|
+-- Settings
    |-- Appearance (theme, app icon)
    |-- Notifications (reminders)
    |-- AI Settings (v0.3.0+)
    |-- Data Management (sync, export)
    +-- About (version, legal)
```

### Navigation Philosophy

| Principle | Implementation |
|-----------|----------------|
| **Flat hierarchy** | Maximum 2 levels deep from any screen |
| **Persistent access** | Tab bar always visible (except full-screen modals) |
| **Context preservation** | Return to exact scroll position when navigating back |
| **Predictable** | Same gesture = same result everywhere |

### Screen Transition Map

```
Today View <---> Calendar View (tab switch)
     |              |
     v              v
Task Detail <---> Schedule on Calendar
     |
     v
Edit Task --> List Picker
         --> Date Picker
         --> Reminder Settings
         --> Recurring Settings
```

---

## Core User Flows

### 1. Quick Task Capture

**Goal**: Add a task with minimal friction

**Success Metric**: < 3 seconds for basic task with title only

```
[Today View]
    |
    +-> Tap "+" FAB (bottom-right, always visible)
    |
    +-> [Add Task Sheet - Medium Detent]
        |
        +-> Keyboard auto-focused on title field
        |
        +-> Type task title (required)
        |
        +-> (Optional) Quick date chips:
        |   - "Today" -> Sets due date to today
        |   - "Tomorrow" -> Sets due date to tomorrow
        |   - "Pick Date" -> Opens date picker
        |
        +-> (Optional) Tap list badge to change list
        |
        +-> Tap "Add" button
            |
            +-> [Haptic: Light impact]
            +-> [Sheet dismisses]
            +-> [Task appears in list with animation]
            +-> [Focus returns to FAB]
```

**Design Decisions**:

| Decision | Rationale |
|----------|-----------|
| FAB always visible | No scrolling needed to add task |
| Title is only required field | Reduce friction, defaults handle rest |
| Quick date chips | Most tasks are today/tomorrow |
| Medium sheet detent | Shows context, doesn't fully block view |
| Auto-focus keyboard | Save a tap |
| Haptic on success | Confirms action without looking |

**Edge Cases**:
- Empty title: Add button disabled, subtle shake on tap
- Very long title: Truncates with "..." in list, full in detail
- Offline: Saves locally, syncs when online (no error shown)

---

### 2. Task Completion

**Goal**: Mark task as done with satisfying feedback

**Success Metric**: < 500ms from tap to visual completion

```
[Task Row]
    |
    +-> Tap checkbox (44pt touch target)
        |
        +-> [Haptic: Success notification]
        +-> [Animation: Checkmark fills with spring bounce]
        +-> [Animation: Row fades to 50% opacity over 150ms]
        +-> [After 2s: Row animates to Completed section]
        |
        +-> (If recurring): Next instance created silently
```

**Design Decisions**:

| Decision | Rationale |
|----------|-----------|
| Large checkbox (44pt) | Accessibility, easy to tap |
| Immediate feedback | Feels responsive |
| Delayed move to Completed | User can see what they did, undo if needed |
| Success haptic | Dopamine hit, reinforces behavior |
| Completed section collapsible | Clean view but history accessible |

**Undo Flow**:
```
[Completed Task Row]
    |
    +-> Tap checkbox again
        |
        +-> [Haptic: Light impact]
        +-> [Task moves back to active list]
```

---

### 3. Task Detail Editing

**Goal**: Modify task properties efficiently

```
[Task Row]
    |
    +-> Tap task title (not checkbox area)
        |
        +-> [Task Detail View - Full Screen Push]
            |
            +-- Title (inline editable, large text)
            +-- Notes (expandable text area)
            +-- [Section: Schedule]
            |   +-- Due Date (date picker)
            |   +-- Due Time (time picker, optional)
            |   +-- Repeat (recurrence picker)
            |
            +-- [Section: Organization]
            |   +-- List (list picker)
            |   +-- Priority (segmented control: None/Low/Medium/High)
            |
            +-- [Section: Reminders]
            |   +-- Remind Me (toggle + options)
            |
            +-- [Section: Actions]
                +-- Delete Task (destructive)
            |
            +-> Changes auto-save on field blur
            +-> Swipe back or tap "Done" to dismiss
```

**Design Decisions**:

| Decision | Rationale |
|----------|-----------|
| Full screen (not sheet) | More space for complex editing |
| Inline title editing | Feels direct, not modal |
| Auto-save | No "unsaved changes" anxiety |
| Grouped sections | Progressive disclosure, less overwhelming |
| Delete at bottom | Prevents accidental taps |

---

### 4. Creating a New List

**Goal**: Organize tasks into projects or categories

```
[Lists View]
    |
    +-> Tap "+" in navigation bar
        |
        +-> [New List Sheet - Medium Detent]
            |
            +-- List Name (text field, auto-focused)
            +-- Color Picker (grid of 12 colors)
            +-- Icon Picker (optional, SF Symbols grid)
            |
            +-> Tap "Create"
                |
                +-> [Haptic: Success]
                +-> [Sheet dismisses]
                +-> [New list appears at bottom of list]
```

**Design Decisions**:

| Decision | Rationale |
|----------|-----------|
| 12 color options | Enough variety, not overwhelming |
| Icon is optional | Keep simple case simple |
| New list at bottom | Preserves user's manual ordering |
| Cannot delete Inbox | Always have a default list |

---

### 5. Setting a Reminder

**Goal**: Get notified at the right time

```
[Task Detail View]
    |
    +-> Toggle "Remind Me" ON
        |
        +-> [Reminder Options - Inline Expansion]
            |
            +-- At due time (default if due time set)
            +-- 15 minutes before
            +-- 1 hour before
            +-- 1 day before
            +-- Custom... (opens time picker)
            |
            +-> Select option
                |
                +-> [Bell icon appears on task row]
                +-> [Local notification scheduled]
```

**Design Decisions**:

| Decision | Rationale |
|----------|-----------|
| Toggle + options | Clear on/off state |
| Common presets | Reduce decision fatigue |
| Custom option | Power users need flexibility |
| Visual indicator | Know at a glance which tasks have reminders |

**Permission Flow**:
```
[First reminder attempt - Notifications not authorized]
    |
    +-> System permission prompt appears
        |
        +-> If denied: Show inline message with "Open Settings" button
```

---

### 6. Creating Recurring Tasks

**Goal**: Set up repeating tasks efficiently

```
[Task Detail View]
    |
    +-> Tap "Repeat" row
        |
        +-> [Recurrence Picker - Sheet]
            |
            +-- Never (default)
            +-- Daily
            +-- Weekly
            |   +-> [Day selector: M T W T F S S]
            +-- Monthly
            |   +-> [Date selector: 1-31 or "Last day"]
            +-- Yearly
            +-- Custom...
            |   +-> Every [N] [days/weeks/months/years]
            |
            +-- End Date (optional)
            |   +-- Never (default)
            |   +-- On date... (date picker)
            |   +-- After N occurrences
            |
            +-> Tap "Done"
                |
                +-> [Repeat icon appears on task row]
```

**Behavior on Completion**:
```
[Complete recurring task]
    |
    +-> Current instance marked complete
    +-> Next instance created with:
        - Same title, notes, list, priority
        - Due date = next occurrence per rule
        - Reminder preserved if relative to due date
```

---

### 7. Search

**Goal**: Find tasks quickly across all lists

```
[Any View with Search Bar]
    |
    +-> Tap search bar / Pull down to reveal
        |
        +-> [Search View - Full Screen]
            |
            +-- Search field (auto-focused)
            +-- [Recent Searches] (if query empty)
            |
            +-> Type query (debounced 300ms)
                |
                +-> [Live Results]
                    |
                    +-- Tasks matching title
                    +-- Tasks matching notes
                    +-- Grouped by list
                    |
                    +-> Tap result
                        |
                        +-> [Task Detail View]
```

**Design Decisions**:

| Decision | Rationale |
|----------|-----------|
| Live results | No submit button, instant feedback |
| Search title AND notes | Users don't remember where they wrote things |
| Recent searches | Quick re-access |
| Debounce 300ms | Prevent excessive searches while typing |

**Performance Target**: Results in < 500ms for 1000 tasks

---

### 8. Calendar Navigation (v0.2.0)

**Goal**: View calendar events and find time slots for tasks

```
[Tab Bar]
    |
    +-> Tap Calendar tab
        |
        +-> [Calendar View]
            |
            +-- View Mode Picker: [Day] [Week]
            +-- Date Navigation: < [Date Range] >
            |
            +-> [Week View - Default]
                |
                +-- 7 day columns with events
                +-- Tap day header to select
                |
                +-> Switch to Day view
                    |
                    +-> [Day View]
                        |
                        +-- Hourly grid (6 AM - 10 PM)
                        +-- Event blocks with calendar colors
                        +-- Task time blocks
```

**Design Decisions**:

| Decision | Rationale |
|----------|-----------|
| Week view default | Overview helps planning |
| Day/Week only (no month) | Focus on actionable time frames |
| Today button in nav bar | Quick return to current date |
| Color-coded events | Match Apple Calendar for familiarity |

---

### 9. Schedule Task to Calendar (v0.2.0)

**Goal**: Block time on calendar for a task

```
[Today View - Task Row]
    |
    +-> Long press and drag task
        |
        +-> [Drag to Calendar Tab]
            |
            +-> [Calendar View with Drop Indicator]
                |
                +-- Hour row highlights on hover
                +-- Drop indicator shows target time
                |
                +-> Release drag
                    |
                    +-> [Time Block Sheet]
                        |
                        +-- Task info (title, notes)
                        +-- Start time picker (pre-filled)
                        +-- Duration picker (15min - 4hr)
                        +-- End time display
                        +-- Preview section
                        |
                        +-> Tap "Create"
                            |
                            +-> [Event created in Apple Calendar]
                            +-> [Task linked to event]
                            +-> [Sheet dismisses]
                            +-> [Event visible in Calendar view]
```

**Design Decisions**:

| Decision | Rationale |
|----------|-----------|
| Drag-and-drop | Natural gesture for scheduling |
| Pre-fill duration | Use task's estimated duration if available |
| Show preview | Confirm before creating calendar event |
| Link task to event | Bidirectional sync |

**Permission Flow**:
```
[First calendar operation - Not authorized]
    |
    +-> Calendar Access Banner appears
        |
        +-> Tap "Enable"
            |
            +-> System permission dialog
                |
                +-> If granted: Banner dismisses, calendar loads
                +-> If denied: Show full-screen "Access Required" view
```

---

### 10. AI Task Analysis (v0.3.0)

**Goal**: Get AI-powered suggestions for task prioritization and scheduling

```
[Add Task View - After entering title]
    |
    +-> AI auto-categorizes task
        |
        +-- Category badge appears (Work, Personal, etc.)
        |
        +-> Tap "Get AI Suggestions" (sparkles icon)
            |
            +-> [Loading state]
                |
                +-> [AI Suggestions Card]
                    |
                    +-- Suggested Priority
                    +-- Estimated Duration
                    +-- Best Time of Day
                    +-- Refined Title (if applicable)
                    +-- Suggested Subtasks
                    |
                    +-> Tap "Apply"
                        |
                        +-> Fields populated with suggestions
                    |
                    +-> Tap "Dismiss"
                        |
                        +-> Card dismisses, keep manual values
```

**Design Decisions**:

| Decision | Rationale |
|----------|-----------|
| Auto-categorize | Reduce friction, show intelligence immediately |
| Optional suggestions | User stays in control |
| Apply/Dismiss options | Non-destructive, user chooses what to keep |
| Show reasoning | Build trust in AI recommendations |

---

### 11. Configure AI Provider (v0.3.0)

**Goal**: Choose and configure LLM provider for AI features

```
[Settings View]
    |
    +-> Tap "AI Provider"
        |
        +-> [AI Provider Selection]
            |
            +-- Apple Intelligence (default if available)
            |   +-- Free, on-device
            |   +-- No API key needed
            |
            +-- Anthropic Claude
            |   +-- Requires API key
            |   +-> Tap to configure
            |       +-> [API Key Entry Sheet]
            |
            +-- OpenAI GPT
                +-- Requires API key
                +-> Tap to configure
                    +-> [API Key Entry Sheet]
```

**Design Decisions**:

| Decision | Rationale |
|----------|-----------|
| Apple Intelligence default | Free, private, no setup |
| BYOK model | User controls costs, no subscription |
| Multiple providers | Flexibility and choice |
| Secure key storage | Keys stored in Keychain |

---

## Empty States

### No Tasks Today

```
+-----------------------------+
|                             |
|     [checkmark icon]        |    64pt icon, accent color
|         (large)             |
|                             |
|        All Clear!           |    Title 1, bold
|                             |
|   You have no tasks due     |    Body, secondary color
|   today. Enjoy your day     |
|   or add a new task.        |
|                             |
|      [ Add Task ]           |    Secondary button
|                             |
+-----------------------------+
```

**Tone**: Celebratory, not empty

---

### No Tasks in List

```
+-----------------------------+
|                             |
|     [list icon]             |    64pt icon, secondary color
|        (large)              |
|                             |
|     No tasks yet            |    Title 1, bold
|                             |
|   Add your first task       |    Body, secondary color
|   to get started.           |
|                             |
|      [ Add Task ]           |    Secondary button
|                             |
+-----------------------------+
```

---

### No Search Results

```
+-----------------------------+
|                             |
|     [magnifying glass]      |    64pt icon, secondary color
|         (large)             |
|                             |
|    No results found         |    Title 1, bold
|                             |
|   Try a different search    |    Body, secondary color
|   term or check spelling.   |
|                             |
+-----------------------------+
```

---

## Error States

### Network Error (Sync)

```
+-------------------------------------------------------+
| [!] Unable to sync. Changes saved locally. [Retry]    |
+-------------------------------------------------------+
```

- Non-blocking banner at top
- Auto-dismisses after 5 seconds
- Manual retry available
- Local-first: user can continue working

---

### Permission Denied (Calendar)

```
+-----------------------------+
|                             |
|     [calendar icon]         |    64pt icon, warning color
|        (large)              |
|                             |
|  Calendar Access Needed     |    Title 1, bold
|                             |
|   To show your events and   |    Body, secondary color
|   schedule tasks, allow     |
|   calendar access.          |
|                             |
|    [ Open Settings ]        |    Primary button
|                             |
+-----------------------------+
```

---

### Permission Denied (Notifications)

```
+-----------------------------+
|                             |
|     [bell icon]             |    64pt icon, warning color
|        (large)              |
|                             |
|  Notifications Disabled     |    Title 1, bold
|                             |
|   Enable notifications to   |    Body, secondary color
|   receive task reminders.   |
|                             |
|    [ Open Settings ]        |    Primary button
|                             |
+-----------------------------+
```

---

## Gesture Interactions

### Swipe Actions on Task Row

| Direction | Short Swipe | Full Swipe |
|-----------|-------------|------------|
| **Right (Leading)** | Reveal complete action | Complete task |
| **Left (Trailing)** | Reveal action menu | Delete task |

**Trailing Action Menu**:
- Edit (pencil icon)
- Move to List (folder icon)
- Delete (trash icon, destructive)

### Pull to Refresh

Available on: Today, Upcoming, Lists, Calendar

- Triggers iCloud sync
- Shows activity indicator in navigation bar
- Haptic feedback on release

### Long Press

| Element | Action |
|---------|--------|
| Task row | Context menu (Complete, Edit, Move, Delete) |
| List row | Context menu (Edit, Delete) |
| Calendar event | Quick view popover |

### Drag and Drop (v0.2.0+)

- Drag task to calendar to schedule
- Drag task between lists
- Drag to reorder tasks within list

---

## Navigation Patterns

### Tab Bar (iPhone)

| Version | Tabs |
|---------|------|
| v0.1.0 | Today, Upcoming, Lists, Settings |
| v0.2.0+ | Today, Calendar, Upcoming, Lists, Settings |

- Selected tab: accent color icon + label
- Unselected: secondary color icon only
- Badge on Today tab: overdue count (red)

### Sidebar (iPad - v0.9.0)

iPad uses NavigationSplitView with a sidebar instead of TabView:

| Section | Items |
|---------|-------|
| Tasks | Today, Calendar, Upcoming |
| Organize | Lists |
| System | Settings |

- Selected item: system selection highlight
- Sidebar width: 260pt
- Collapsible with toggle button
- Toolbar: Add task (+), Search (magnifying glass)

### Sheet Presentation

| Content | Detent | Dismissal |
|---------|--------|-----------|
| Add Task | Medium (50%) | Swipe down, tap outside, tap Add |
| New List | Medium (50%) | Swipe down, tap outside, tap Create |
| Date Picker | Large (90%) | Swipe down, tap Done |
| Task Detail | Full screen | Back button, swipe from edge |

### Back Navigation

- Swipe from left edge (iOS standard)
- Back button in navigation bar
- Auto-save before navigating away

---

## Accessibility

### VoiceOver Announcements

| Event | Announcement |
|-------|--------------|
| Task completed | "Completed: [task title]" |
| Task added | "Added task: [task title]" |
| Task deleted | "Deleted: [task title]" |
| Error | "Error: [message]" |
| Sync complete | "Sync complete" |

### Custom Actions

**Task Row**:
- Activate: Open task detail
- Custom action 1: Mark complete / Mark incomplete
- Custom action 2: Delete

**List Row**:
- Activate: Open list
- Custom action 1: Edit list
- Custom action 2: Delete list (if not Inbox)

### Focus Management

| Event | Focus Target |
|-------|--------------|
| Add task complete | FAB (ready for next add) |
| Task completed | Next task in list |
| Task deleted | Next task in list |
| Error appears | Error message |
| Modal dismissed | Element that triggered modal |
| Search opened | Search field |

### Reduce Motion

When `UIAccessibility.isReduceMotionEnabled`:
- Disable spring animations
- Use cross-fade instead of slide transitions
- Instant checkbox state change (no animation)

---

## Performance Requirements

### Response Time Targets

| Action | Target | Measurement |
|--------|--------|-------------|
| App launch (cold) | < 2s | Time to interactive |
| App launch (warm) | < 500ms | Time to interactive |
| Task creation | < 1s | Tap Add to task visible |
| Task completion | < 500ms | Tap to animation complete |
| Search results | < 500ms | Query to results visible |
| Calendar render | < 1s | Tab switch to calendar visible |
| Scroll | 60 FPS | No dropped frames |

### Data Limits

| Item | Soft Limit | Hard Limit |
|------|------------|------------|
| Task title | 100 chars | 500 chars |
| Task notes | 1000 chars | 10000 chars |
| Lists | 20 | 100 |
| Tasks per list | 100 | 1000 |
| Total tasks | 1000 | 10000 |

---

## Version History

See [CHANGELOG.md](../../CHANGELOG.md) for detailed release history.
