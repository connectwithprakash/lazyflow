# Changelog

All notable changes to Taskweave will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.12.0] - 2026-01-01

### Added
- Branded launch screen with app background color for smoother visual transition
- VoiceOver accessibility labels on task rows (status, title, priority, due date, category)
- UTType declaration for task drag & drop support

### Changed
- UpcomingView converted from ScrollView to List for native swipe action support
- ListDetailView converted from ScrollView to List for native swipe action support
- Defer heavy initialization to after UI appears for faster perceived startup

### Fixed
- Remove fatalError in PersistenceController (graceful error handling instead)
- Fix force unwraps in TaskService date calculations
- Fix force unwraps in CalendarView week/hour calculations
- Fix force unwraps in SmartRescheduleService tomorrow calculation
- Fix force unwraps in Date+Extensions (isWithinNextWeek, endOfDay, currentWeekDates)

## [0.11.0] - 2026-01-01

### Added
- Native swipe actions on task rows
  - Swipe left: Delete, Move to Today, Push to Tomorrow (contextual)
  - Swipe right: Complete/Undo (full swipe), Schedule to Calendar
- Haptic feedback on swipe actions
- Undo toast notification for task actions (complete, delete, reschedule)
- Move to Today action for overdue and upcoming tasks

### Changed
- TodayView converted from ScrollView to List for native swipe support
- List styled with plain style and hidden separators to match existing design

## [0.10.0] - 2025-12-31

### Changed
- Replace priority badges with left edge color strips for cleaner visual hierarchy
- Priority colors: Urgent (red), High (orange), Medium (yellow), Low (blue)
- Keep checkbox ring color as secondary priority signal

### Fixed
- Wire up context menu actions for priority, due date, and delete
- Fix badge text wrapping with lineLimit and fixedSize
- Clip task rows with RoundedRectangle for proper corner radius

## [0.9.0] - 2025-12-31

### Added
- iPad-optimized UI with NavigationSplitView sidebar navigation
- Adaptive layout: Sidebar for iPad (regular size class), TabView for iPhone (compact)
- Keyboard shortcuts for iPad: Cmd+N (new task), Cmd+F (search), Cmd+1-5 (navigate tabs)
- Proper iOS List selection binding for sidebar navigation
- Size class detection across all views (TodayView, CalendarView, UpcomingView, ListsView, SettingsView)
- Conditional NavigationStack wrapping based on device type

### Changed
- ContentView refactored to support both NavigationSplitView and TabView
- Views now detect horizontalSizeClass to adapt layout

## [0.8.0] - 2025-12-31

### Added
- Apple Watch app with SwiftUI for watchOS 10+
- Today's task list view with progress ring header
- Tap-to-complete task interaction
- WatchConnectivity for real-time iPhone ↔ Watch sync
- Watch complications (circular, corner, inline, rectangular)
- WatchDataStore for offline task caching via App Groups

## [0.7.0] - 2025-12-31

### Added
- Lock Screen Live Activity with centered progress ring and task hierarchy
- Dynamic Island compact view with progress ring and subtle progress bar
- Dynamic Island expanded view showing current task with upcoming breadcrumb
- Dynamic Island minimal view for multi-activity mode
- Settings toggle to enable/disable Live Activity tracking
- LiveActivityManager for activity lifecycle management

## [0.6.0] - 2025-12-31

### Added
- iOS Home Screen Widgets via WidgetKit
- Small widget showing task count and completion progress
- Medium widget displaying today's task list with priorities
- Large widget with overdue, today, and upcoming sections
- App Groups for shared data between app and widgets
- Widget refresh on task changes

## [0.5.0] - 2025-12-31

### Added
- Siri Shortcuts integration via App Intents
- "Create Task" shortcut for hands-free task creation
- "Complete Next Task" shortcut to mark tasks done
- "Get Today's Tasks" shortcut to hear your agenda
- Shortcuts appear automatically in the Shortcuts app

## [0.4.0] - 2025-12-31

### Added
- Smart rescheduling when meetings conflict
- Conflict detection service for task-calendar conflicts
- "What should I do next?" AI-powered prioritization
- Time protection for focused work blocks
- Push-to-tomorrow swipe action for tasks
- Unit and UI tests for smart rescheduling

## [0.3.0] - 2025-12-30

### Added
- Multi-provider LLM support (Apple Intelligence, Anthropic Claude, OpenAI)
- AI-powered task analysis and suggestions
- ML-based automatic task categorization using Create ML
- Color-coded category badges (Work, Personal, Health, Finance, etc.)
- Provider selection in Settings with API key configuration

## [0.2.0] - 2025-12-30

### Added
- Native Apple Calendar integration via EventKit
- Day and week calendar views
- Calendar view with events display
- Schedule tasks as time blocks
- CalendarService for event management
- CalendarViewModel for calendar state

## [0.1.0] - 2025-12-29

### Added
- Core task management with CRUD operations
- Task lists for organization
- Due dates and time-based reminders
- Recurring tasks (daily, weekly, monthly, yearly)
- Priority levels (urgent, high, medium, low, none)
- Core Data persistence for offline-first experience
- CloudKit sync for iCloud backup
- Today view with overdue and today's tasks
- Upcoming view for future tasks
- Lists view for task organization
- Settings view with appearance options
- Light and dark mode support
- Tab bar navigation
- SwiftUI native interface
- VoiceOver accessibility support
