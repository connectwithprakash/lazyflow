# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

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
- Use external references for additional context when needed
- Research solutions when encountering issues
- Follow Swift/iOS community best practices

**DEVELOPMENT WORKFLOW:**
1. **Pull:** Always pull `origin/main` before starting work
2. **Branch:** Create a branch linked to GitHub issue (e.g., `feat/123-feature-name` or `fix/123-bug-name`)
3. **Research:** Read the GitHub issue thoroughly, explore related code, understand the problem space
4. **Learn:** Search the web for best practices, patterns, and approaches given our tech stack (Swift, SwiftUI, Core Data, Apple Intelligence)
5. **Plan:** Design the implementation approach, identify files to modify, verify assumptions
6. **TDD:** Write tests first, then implement to make them pass
7. **Implement:** Code the feature/fix iteratively with small commits
8. **Test:**
   - Run unit tests
   - Run UI tests on iPhone 17 Pro and iPad simulators
   - Manual testing on simulators
   - Manual testing on physical iPhone (if available)
9. **Commit:** Create small, iterative commits with clear messages
10. **Document:** Iteratively review `docs/` and update relevant documentation:
    - `docs/project/` - Check roadmap, user-flows, design-system for updates
    - `fastlane/metadata/en-US/release_notes.txt` - Add to What's New
    - `fastlane/metadata/en-US/promotional_text.txt` - Update promotional text
    - `README.md` - Update if major features change app capabilities
    - Screenshots (if UI changed):
      - Take screenshots in iOS Simulator (iPhone 17 Pro) in both light and dark modes
      - Save to `docs/site/assets/screenshots/light/` and `docs/site/assets/screenshots/dark/`
      - Use numbered naming convention (e.g., `21-feature-name.png`)
      - Add to `docs/site/design/index.html` (not the main landing page)
      - Update the design system version in the footer
    - Deploy website: `netlify deploy --prod --dir=docs/site`
11. **PR:** Do NOT push or create PR without explicit permission from the user

## Project Overview

Lazyflow is an AI-powered, calendar-integrated todo app for iOS. The core value proposition is helping us plan our day - see calendar events alongside tasks, schedule tasks as time blocks, and get AI-powered "What should I do next?" recommendations with daily summaries.

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Database:** Core Data (offline-first)
- **Cloud:** CloudKit (iCloud sync)
- **Calendar:** EventKit (Apple Calendar integration)
- **AI:** Apple Intelligence (on-device task estimation/prioritization)
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
- **v1.3.3:** Removed external LLM providers (Claude, OpenAI) - Now Apple Intelligence only
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
Hosted on Netlify at lazyflow.netlify.app:
- `index.html` - Landing page
- `privacy/` - Privacy Policy
- `terms/` - Terms of Service

### Project Documentation (`docs/project/`)
- `roadmap.md` - Project roadmap and features
- `design-system.md` - Colors, typography, spacing, components
- `user-flows.md` - User journeys and interaction patterns
- `architecture.md` - Technical architecture (added in v0.5.1)
- `deployment.md` - Fastlane setup and deployment guide

## Deployment

The app uses Fastlane for automated deployments with GitHub Actions CI/CD.

### Fastlane Lanes

```bash
# Deploy to TestFlight (local)
export MATCH_PASSWORD="password"
bundle exec fastlane beta

# Submit to App Store Review
bundle exec fastlane submit_for_review

# Upload screenshots only
bundle exec fastlane upload_screenshots
```

### GitHub Actions Workflows

- **Release** (`.github/workflows/release.yml`) - Triggered on push to main
  - Creates GitHub release via Release Please
  - Bumps iOS version numbers
  - Deploys to TestFlight automatically

- **App Store** (`.github/workflows/appstore.yml`) - Manual trigger
  - Uploads screenshots from `docs/assets/screenshots/appstore/`
  - Uploads metadata from `fastlane/metadata/`
  - Submits latest TestFlight build for App Store review

### App Store Metadata

Located in `fastlane/metadata/en-US/`:
- `name.txt` - App name
- `subtitle.txt` - App subtitle
- `description.txt` - Full description
- `keywords.txt` - Search keywords (comma-separated)
- `release_notes.txt` - What's New for current version
- `privacy_url.txt`, `support_url.txt`, `marketing_url.txt`

### Screenshots

- **App Store** (`docs/assets/screenshots/appstore/`) - 1284x2778 iPhone 6.5"
- **Website** (`docs/site/assets/screenshots/`) - Light and dark mode

See `docs/project/deployment.md` for full setup instructions.
