# Changelog

All notable changes to Taskweave will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
