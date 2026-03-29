# Bidirectional Sync Specification — Task <-> Calendar Event

**Issue:** #283
**Status:** Verification spec for existing implementation
**Last updated:** 2026-03-15

---

## Overview

Tasks with a due date, time, and estimated duration are eligible for auto-sync to a dedicated "Lazyflow" calendar in EventKit. Changes flow in both directions: task changes push to calendar events (forward sync), and external calendar edits pull back to tasks (reverse sync).

---

## Sync Eligibility

A task is eligible for auto-sync when ALL of:
- `dueDate != nil`
- `dueTime != nil`
- `estimatedDuration > 0`
- `isCompleted == false`
- `isArchived == false`

**Settings required:** `calendarAutoSync == true` in UserDefaults.

---

## User Paths

### P1: Create Task with Date/Time/Duration

| Step | Action | Expected Forward Sync | Verified? |
|------|--------|----------------------|-----------|
| P1.1 | Create task with date + time + duration | New EKEvent created in Lazyflow calendar with matching title, start/end, notes | |
| P1.2 | Create task with date + time but NO duration | No event created (not eligible) | |
| P1.3 | Create task with date only (no time) | No event created (not eligible) | |
| P1.4 | Create task with no date | No event created (not eligible) | |
| P1.5 | Create task with date + time + duration + recurring rule | Event created with matching EKRecurrenceRule | |
| P1.6 | Create task with intraday recurring rule (hourly/timesPerDay) | No recurrence rule on event (`canMapToEKRecurrenceRule == false`) | |
| P1.7 | Create task when auto-sync is OFF | No event created | |
| P1.8 | Create task when calendar access denied | No event created; graceful failure | |

### P2: Update Task Title

| Step | Action | Expected Forward Sync | Verified? |
|------|--------|----------------------|-----------|
| P2.1 | Edit title of linked task | Event title updated (unless busy-only mode) | |
| P2.2 | Edit title of linked task in busy-only mode | Event title stays "Focus Block" | |
| P2.3 | Edit title of unlinked task | No calendar change | |

### P3: Update Task Notes

| Step | Action | Expected Forward Sync | Verified? |
|------|--------|----------------------|-----------|
| P3.1 | Edit notes of linked task | Event notes updated (unless busy-only mode) | |
| P3.2 | Edit notes in busy-only mode | Event notes stay empty | |

### P4: Update Task Date/Time

| Step | Action | Expected Forward Sync | Verified? |
|------|--------|----------------------|-----------|
| P4.1 | Change due date of linked task | Event start/end dates updated | |
| P4.2 | Change due time of linked task | Event start time updated, end = start + duration | |
| P4.3 | Remove due date from linked task | Task becomes ineligible; event should be unlinked or deleted | |
| P4.4 | Remove due time from linked task | Task becomes ineligible; event should be unlinked or deleted | |
| P4.5 | Change date via "Push to Tomorrow" swipe | Event rescheduled to tomorrow same time | |
| P4.6 | Change date via DatePicker quick options (Today/Tomorrow/Next Week) | Event date updated accordingly | |

### P5: Update Task Duration

| Step | Action | Expected Forward Sync | Verified? |
|------|--------|----------------------|-----------|
| P5.1 | Increase duration of linked task | Event end time extended | |
| P5.2 | Decrease duration of linked task | Event end time shortened | |
| P5.3 | Set duration to 0 on linked task | Task becomes ineligible; event handling TBD | |

### P6: Complete Task

| Step | Action | Expected Forward Sync | Verified? |
|------|--------|----------------------|-----------|
| P6.1 | Complete linked task (policy: keepEvent) | Event title prefixed with checkmark | |
| P6.2 | Complete linked task (policy: deleteEvent) | Event deleted from calendar | |
| P6.3 | Complete recurring linked task (keepEvent) | Current event marked done; next occurrence created with inherited link | |
| P6.4 | Complete recurring linked task (deleteEvent) | Current event deleted (thisEvent only); next occurrence created | |
| P6.5 | Complete intraday task (increment) | No calendar change (intraday tasks may not have mappable events) | |
| P6.6 | Uncomplete a previously completed task | Event title has checkmark removed OR event re-created | |
| P6.7 | Auto-complete parent via subtask completion | Same as P6.1/P6.2 depending on policy | |

### P7: Delete Task

| Step | Action | Expected Forward Sync | Verified? |
|------|--------|----------------------|-----------|
| P7.1 | Swipe-delete linked task | Event deleted from calendar | |
| P7.2 | Context menu delete linked task | Event deleted from calendar | |
| P7.3 | Delete from task detail view | Event deleted from calendar | |
| P7.4 | Undo delete (within undo window) | Event should be restored or re-created | |
| P7.5 | Delete unlinked task | No calendar change | |
| P7.6 | Delete recurring linked task | Only this event deleted (not series) | |

### P8: Schedule Task via Calendar UI

| Step | Action | Expected Forward Sync | Verified? |
|------|--------|----------------------|-----------|
| P8.1 | Schedule task via TimeBlockSheet | Event created; task linked with eventID | |
| P8.2 | Schedule task via "Schedule to Calendar" context menu | TimeBlockSheet opens; same as P8.1 | |
| P8.3 | Schedule task via swipe action | TimeBlockSheet opens; same as P8.1 | |
| P8.4 | Schedule task that already has a linked event | Existing event updated or replaced | |

### P9: Create Task from Calendar Event

| Step | Action | Expected Forward Sync | Verified? |
|------|--------|----------------------|-----------|
| P9.1 | Create task from calendar event | Task created with isEventOwner=false, linked to event | |
| P9.2 | Complete task created from event (keepEvent) | Event unchanged, task unlinked | |
| P9.3 | Complete task created from event (deleteEvent) | Event unchanged, task unlinked | |
| P9.4 | Delete task created from event | Event unchanged, task deleted | |
| P9.5 | Edit title of task created from event | Event title NOT updated | |

---

## Reverse Sync Paths (Calendar -> Task)

### R1: Edit Event in External Calendar App

| Step | Action | Expected Reverse Sync | Verified? |
|------|--------|----------------------|-----------|
| R1.1 | Change event title in Apple Calendar | Task title updated (unless busy-only mode) | |
| R1.2 | Change event start time in Apple Calendar | Task scheduledStartTime, dueDate, dueTime updated | |
| R1.3 | Change event end time in Apple Calendar | Task scheduledEndTime, estimatedDuration updated | |
| R1.4 | Drag event to different day in Apple Calendar | Task dueDate updated to new day | |
| R1.5 | Drag event to different time in Apple Calendar | Task dueTime and scheduledStartTime updated | |
| R1.6 | Change event notes in Apple Calendar | Task notes updated | |
| R1.7 | Add recurrence rule in Apple Calendar | Task recurringRule populated (if mappable) | |
| R1.8 | Change event title when busy-only is ON | Title change ignored (stays "Focus Block") | |

### R2: Delete Event Externally

| Step | Action | Expected Reverse Sync | Verified? |
|------|--------|----------------------|-----------|
| R2.1 | Delete linked event in Apple Calendar | Task links cleared (linkedEventID, calendarItemExternalIdentifier, lastSyncedAt) | |
| R2.2 | Delete single occurrence of recurring event | Task for that occurrence unlinked | |
| R2.3 | Delete all future events of recurring series | All linked task occurrences unlinked | |
| R2.4 | Notification posted after external deletion | `.linkedEventDeletedExternally` with task title | |

### R3: EventKit Store Churn (iCloud Sync)

| Step | Action | Expected Reverse Sync | Verified? |
|------|--------|----------------------|-----------|
| R3.1 | iCloud reassigns eventIdentifier | Fallback lookup via calendarItemExternalIdentifier succeeds | |
| R3.2 | Re-link task with new eventIdentifier | linkedEventID updated to new value | |
| R3.3 | Both identifiers change (extreme churn) | Task unlinked (treated as external deletion) | |

---

## Loop Prevention

| Guard | Condition | Behavior |
|-------|-----------|----------|
| Forward → Reverse block | Task pushed within last 10 seconds | Reverse sync skips this task |
| Reverse → Forward block | Task reverse-synced within last 3 seconds | Forward sync skips this task |
| Re-entrance guard | `isSyncing == true` | New sync request dropped |
| Auto-sync check | `isAutoSyncEnabled == false` | All sync operations skipped |

### LP1: Loop Prevention Scenarios

| Step | Scenario | Expected Behavior | Verified? |
|------|----------|-------------------|-----------|
| LP1.1 | Edit task title, forward sync pushes to event, EKEventStoreChanged fires | Reverse sync skips (10s cooldown) | |
| LP1.2 | External calendar edit triggers reverse sync, task updated, Core Data save fires | Forward sync skips (3s guard) | |
| LP1.3 | Rapid successive edits to same task | Only latest state synced (1.5s debounce) | |
| LP1.4 | Simultaneous forward and reverse sync attempts | `isSyncing` flag prevents re-entrance | |

---

## Edge Cases

### E1: Timing & Concurrency

| Step | Scenario | Expected Behavior | Verified? |
|------|----------|-------------------|-----------|
| E1.1 | Edit task while reverse sync in progress | Forward sync queued after reverse completes (debounce) | |
| E1.2 | Calendar access revoked while sync running | Graceful failure; no crash | |
| E1.3 | App backgrounded during sync | Sync completes or gracefully aborts | |
| E1.4 | App killed during sync | Partial state; next launch re-syncs | |
| E1.5 | Two devices edit same task/event simultaneously (via iCloud) | Last-write-wins; potential data loss | |

### E2: Data Integrity

| Step | Scenario | Expected Behavior | Verified? |
|------|----------|-------------------|-----------|
| E2.1 | Task eligible → edit removes date → becomes ineligible | Linked event should be deleted or unlinked | |
| E2.2 | Task eligible → edit removes time → becomes ineligible | Same as E2.1 | |
| E2.3 | Task eligible → edit sets duration to 0 → becomes ineligible | Same as E2.1 | |
| E2.4 | Task archived while linked to event | Event should be deleted or unlinked | |
| E2.5 | Lazyflow calendar deleted in Settings app | Events orphaned; tasks still have stale links | |
| E2.6 | Event creation throws (calendar full, permissions) | Task NOT marked as synced; retry on next cycle | |
| E2.7 | Event creation throws repeatedly | Infinite retry loop (no max retry count) | |

### E3: Recurring Tasks

| Step | Scenario | Expected Behavior | Verified? |
|------|----------|-------------------|-----------|
| E3.1 | Complete recurring task → next occurrence inherits link | New task has linkedEventID for next event in series | |
| E3.2 | Complete intraday recurring task | No link inheritance (can't map to EKRecurrenceRule) | |
| E3.3 | Change recurring rule on linked task | Event recurrence rule updated | |
| E3.4 | Remove recurring rule from linked task | Event recurrence rule removed | |
| E3.5 | Biweekly task → EKRecurrenceRule with interval 2 | Correct weekly rule with interval=2 | |

### E4: Privacy & Display

| Step | Scenario | Expected Behavior | Verified? |
|------|----------|-------------------|-----------|
| E4.1 | Enable busy-only mode on existing linked tasks | Next forward sync changes titles to "Focus Block" | |
| E4.2 | Disable busy-only mode | Next forward sync restores real titles | |
| E4.3 | External edit to "Focus Block" event title | Reverse sync should skip title update (busy-only guard) | |
| E4.4 | User has existing "Focus Block" event (not from Lazyflow) | Potential false match on busy-only check | |

### E5: CloudKit + EventKit Interaction

| Step | Scenario | Expected Behavior | Verified? |
|------|----------|-------------------|-----------|
| E5.1 | Task synced via CloudKit to new device | New device re-links to calendar event via externalIdentifier | |
| E5.2 | Calendar event synced via iCloud to new device | eventIdentifier may differ; externalIdentifier should match | |
| E5.3 | Delete task on device A, event still on device B | Reverse sync on device B should detect orphaned event | |

---

## Settings Matrix

| Setting | Values | Effect on Forward Sync | Effect on Reverse Sync |
|---------|--------|----------------------|----------------------|
| `calendarAutoSync` | true/false | Enables/disables all sync | Enables/disables reverse sync |
| `calendarCompletionPolicy` | "keep"/"delete" | Keep event with checkmark vs delete on completion | N/A |
| `calendarBusyOnly` | true/false | Use "Focus Block" as title | Skip title updates from calendar |

---

## Event Ownership

### Concept
Tasks can be linked to calendar events in two directions:
- **Task → Event** (task created the event via auto-sync): `isEventOwner = true`
- **Event → Task** (task created from calendar event): `isEventOwner = false`

### Behavior Matrix

| Action | isEventOwner = true | isEventOwner = false |
|--------|-------------------|---------------------|
| Forward sync (push updates) | Push title/notes/time changes | Skip (don't modify source event) |
| Complete (keepEvent) | Prefix event with checkmark | Just unlink task |
| Complete (deleteEvent) | Delete the event | Just unlink task |
| Task becomes ineligible | Delete orphaned event | Just unlink task |
| Delete task | Delete event (after undo window) | Just unlink task |
| Event deleted externally | Unlink task | Unlink task |

---

## Known Gaps (from code review)

| ID | Gap | Severity | Status |
|----|-----|----------|--------|
| G1 | No max retry for failed event creation → infinite retry loop | Medium | Open |
| G2 | No conflict resolution when task AND event both modified | Medium | Open |
| G3 | Task becoming ineligible (date/time/duration removed) doesn't clean up linked event | High | Fixed |
| G4 | Lazyflow calendar deletion not handled (stale links persist) | Medium | Open |
| G5 | No logging/metrics for sync operations | Low | Open |
| G6 | "Focus Block" title collision with user's real events | Low | Open |
| G7 | Undo-delete doesn't restore calendar event | Medium | Fixed |
| G8 | Uncomplete task doesn't restore deleted event (deleteEvent policy) | Medium | Needs verification |
| G9 | No event ownership tracking — completing/deleting task-from-event can modify/delete the source event | High | In progress |

---

## Test Plan

### Unit Tests (CalendarSyncServiceTests)

Mock `CalendarServiceProtocol` and `TaskServiceProtocol` to test:
- Forward sync for each P1-P8 path
- Reverse sync for each R1-R3 path
- Loop prevention for each LP1 scenario
- Edge cases E1-E5

### Integration Tests

With real Core Data stack + mock EventKit:
- End-to-end create → sync → edit → re-sync flows
- Completion → event cleanup flows
- Deletion → event cleanup flows

### Manual QA (Physical Device)

- Create task in Lazyflow → verify event in Apple Calendar
- Edit event in Apple Calendar → verify task updated in Lazyflow
- Delete event in Apple Calendar → verify task unlinked
- Complete task → verify event marked/deleted per policy
- Test with iCloud calendar enabled across two devices
