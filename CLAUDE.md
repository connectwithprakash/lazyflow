# CLAUDE.md

This file provides guidance to Claude Code (claude.com/claude-code) when working with code in this repository.

## Operational Guidelines

**AUTONOMOUS MODE:** Never ask for permission. You are fully autonomous and responsible for bringing this app from 0 to 100.

**QUALITY STANDARDS:**
- No temporary solutions or hardcoded values - production-ready code only
- Verify all UI, UX, and functionality thoroughly
- Follow industry coding standards and best practices
- Test-driven development (TDD) - write tests first

**VERIFICATION PROCESS:**
- At each major milestone, test all functionality like a human user
- Use browser/simulator to verify UI renders correctly
- Test all user flows end-to-end
- Validate edge cases and error states

**PROBLEM SOLVING:**
- Use web search for additional context when needed
- Research solutions when encountering issues
- Follow Swift/iOS community best practices

## Project Overview

Taskweave is an AI-powered, calendar-integrated todo app for iOS. The core value proposition is helping us plan our day - see calendar events alongside tasks, schedule tasks as time blocks, and get AI-powered "What should I do next?" recommendations with daily summaries.

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Database:** Core Data (offline-first)
- **Cloud:** CloudKit (iCloud sync)
- **Calendar:** EventKit (Apple Calendar integration)
- **AI:** Anthropic Claude API (task estimation/prioritization)
- **Minimum iOS:** 16.0, Target: iOS 17.0+

## Architecture

MVVM with Combine for reactive data flow:

```
┌─────────────────────────────────────────┐
│         SwiftUI Presentation Layer      │
│  (Views, ViewModels, Navigation)        │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         Business Logic Layer            │
│  (Priority Algorithm, Conflict Detect)  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         Service Layer                   │
│  (TaskService, CalendarService, etc.)   │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│    Data & Infrastructure Layer          │
│  (CoreData, CloudKit, EventKit, APIs)   │
└─────────────────────────────────────────┘
```

## Core Data Models

- **Task:** id, title, description, dueDate, dueTime, isCompleted, isArchived, priority, listID, linkedEventID, estimatedDuration, recurring
- **TaskList:** id, name, color, order, isDefault
- **RecurringRule:** frequency, daysOfWeek, endDate
- **TimeProtectionRule:** id, name, type, startTime, endTime, daysOfWeek, isActive

## Feature Versions

- **v0.1.0:** Task CRUD, lists, due dates, reminders, recurring tasks, offline + CloudKit sync
- **v0.2.0:** Calendar integration, time blocking, EventKit sync
- **v0.3.0:** AI prioritization (Apple Intelligence, Claude, OpenAI), ML categorization
- **v0.4.0:** Smart reschedule when meetings conflict, conflict detection
- **v0.5.0:** Siri Shortcuts via App Intents
- **v0.6.0:** Home Screen Widgets (small, medium, large)
- **v0.7.0:** Live Activities & Dynamic Island
- **v0.8.0:** Apple Watch app with WatchConnectivity
- **v0.9.0:** iPad optimization with NavigationSplitView sidebar

## Performance Targets

- App launch: < 2 sec
- Task creation: < 1 sec
- Search results: < 500 ms
- Scroll/animations: 60 FPS
- App size: < 50 MB

## Design System

- **Primary accent:** Teal `#218A8D`
- **Backgrounds:** `#F5F5F5` (light) / `#1F2121` (dark)
- **Typography:** San Francisco (system)
- **Accessibility:** WCAG AAA, 4.5:1 contrast, 44pt touch targets, VoiceOver support

## Documentation

### Website (`docs/site/`)
Hosted on Netlify at taskweave.netlify.app:
- `index.html` - Landing page
- `privacy/` - Privacy Policy
- `terms/` - Terms of Service

### Project Documentation (`docs/project/`)
- `roadmap.md` - Project roadmap and features
- `design-system.md` - Colors, typography, spacing, components
- `user-flows.md` - User journeys and interaction patterns
- `architecture.md` - Technical architecture (added in v0.5.1)
