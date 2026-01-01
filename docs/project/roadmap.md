# Taskweave Roadmap

A calendar-first todo app for iOS that makes task scheduling as natural as writing a todo.

## Vision

Calendar and tasks finally work together. Taskweave is where you protect deep work, see what's real, and let AI handle the scheduling complexity.

## Target Users

### Primary: Engineers & Technical Teams
- Heavy calendar users (meetings 2-3 hrs/day)
- Need to see tasks + calendar together
- Want AI to help prioritize and estimate work
- Value deep work protection

### Secondary: Knowledge Workers
- Product managers, designers, remote workers
- Calendar overbooked, need better organization
- Want smart prioritization

## Feature Roadmap

### v0.1.0 - Core Essentials
- Task management (create, edit, delete, complete)
- Lists/Projects organization
- Due dates and smart reminders
- Recurring tasks (daily, weekly, monthly)
- Offline-first with CloudKit sync
- Search and filtering

### v0.2.0 - Calendar Integration
- Apple Calendar read/write access
- Drag task to calendar (time-blocking)
- Split view: tasks + calendar
- Bidirectional sync with EventKit

### v0.3.0 - AI Prioritization
- Multiple AI provider support:
  - Apple Intelligence (free, on-device)
  - Claude API (bring your own key)
  - OpenAI API (bring your own key)
- GitHub integration (issues to tasks)
- Auto-prioritization algorithm
- "What should I do next?" suggestions

### v0.4.0 - Smart Rescheduling
- Meeting conflict detection
- AI task rearrangement suggestions
- Time protection rules (e.g., no tasks after 6 PM)
- Auto-apply option with user review

### v0.5.0 - Siri Integration
- Siri shortcuts support via App Intents
- "Add a task" voice command
- "Complete next task" voice command
- "What's on my agenda" voice command

### v0.6.0 - Home Screen Widgets
- Small widget: circular progress ring with task count
- Medium widget: today's task list with priority indicators
- Large widget: sectioned view (overdue, today, upcoming)
- App Groups for shared data between app and widget

### v0.7.0 - Live Activities & Dynamic Island
- Lock Screen Live Activity with task progress
- Dynamic Island compact view (task count + current task)
- Dynamic Island expanded view (progress bar, next task)
- Settings toggle to enable/disable tracking
- Auto-updates when tasks are completed

### v0.8.0 - Apple Watch
- Apple Watch app with SwiftUI
- Task list on wrist (today's tasks)
- Quick task completion via tap
- WatchConnectivity for real-time sync
- Complications: circular progress, inline count, rectangular preview

### v0.9.0 - iPad Optimization ✅ Current
- NavigationSplitView with sidebar for iPad
- Adaptive layout (sidebar on iPad, TabView on iPhone)
- Size class detection across all views
- Keyboard shortcuts (Cmd+N, Cmd+F, Cmd+1-5) for Mac Catalyst
- Proper iOS List selection binding

### Future Considerations
- Mac Catalyst app
- Team collaboration features
- Additional calendar integrations (Google, Outlook)

## Technical Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Database:** Core Data (offline-first)
- **Cloud:** CloudKit (iCloud sync)
- **Calendar:** EventKit
- **AI:** Pluggable providers (Apple Intelligence, Claude, OpenAI)
- **Minimum iOS:** 17.0

## Design Principles

1. **Simplicity** - Match Apple Reminders on essentials, don't bloat
2. **Calendar-first** - Tasks and calendar should feel like one experience
3. **Privacy-focused** - Local processing, user owns all data
4. **Accessible** - WCAG AAA compliant, VoiceOver support
5. **Native** - Deep Apple ecosystem integration

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for how to contribute to this roadmap and the project.

## User Stories

### Time Blocking
> As a remote engineer, when I have a 2-hour code review, I can drag the task to a free calendar slot. It creates a calendar event so I protect that time from meetings.

### Smart Reschedule
> As an engineer with protected deep work blocks, when a meeting is added during my focus time, the app suggests rescheduling lower-priority tasks. I review and approve, and my calendar updates automatically.

### Quick Capture
> As a busy professional, I can quickly add a task with natural language like "Call mom tomorrow 3 PM" and it parses the due date automatically.
