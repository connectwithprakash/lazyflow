# Lazyflow Architecture

Last updated: v1.10.0

## Overview

Lazyflow is a SwiftUI iOS app using MVVM architecture with Core Data persistence, CloudKit sync, and EventKit calendar integration. The codebase is organized into SPM local packages for shared code and the main app target for features.

## Project Structure

```
Lazyflow/
├── Packages/
│   ├── LazyflowCore/          # Shared models, extensions, utilities
│   └── LazyflowUI/            # Design system tokens and UI components
├── Lazyflow/
│   └── Sources/
│       ├── App/               # App entry point, RootView
│       ├── Extensions/        # App-specific extensions (Core Data entities)
│       ├── Intents/           # Siri Shortcuts and App Intents
│       ├── Models/            # Core Data model (.xcdatamodeld)
│       ├── Services/          # Business logic layer
│       │   ├── AI/            # LLM providers, prompt templates
│       │   └── Protocols/     # Service protocols for DI
│       ├── Utilities/         # Feature flags, configuration
│       ├── ViewModels/        # @Observable ViewModels
│       └── Views/             # SwiftUI views
│           ├── AddTask/       # Split: AddTaskView, QuickActions, date/list pickers
│           ├── Components/    # Shared UI components
│           ├── Settings/      # Split: SettingsView, AI, About, Notifications, etc.
│           ├── Sheets/        # Modal sheets
│           └── Today/         # Split: TodayView, NextUp, Sections, etc.
├── LazyflowWidget/            # Home Screen and Lock Screen widgets
├── LazyflowWatch/             # Apple Watch app
├── LazyflowTests/             # Unit and snapshot tests
└── LazyflowUITests/           # UI automation tests
```

## SPM Local Packages

### LazyflowCore

Shared foundation layer with no UIKit/SwiftUI dependency. Used by the app, widget, and watch targets.

**Contents:**
- `Extensions/` — `Color+Extensions`, `Date+Extensions`, `Logger+Extensions`
- `Models/` — `Task`, `QuickNote`, `RecurringRule`, `Priority`, `TaskCategory`, `TaskDraft`, `TaskList`, `CustomCategory`, `BehavioralSignals`, `CompletionPatterns`, `SuggestionFeedback`, `DailySummaryData`, `PlanYourDayData`
- `Models/AI/` — AI-related data models
- `Utilities/` — `AppConstants`

```
Package: LazyflowCore
Platforms: iOS 17+, watchOS 10+
Dependencies: none
```

### LazyflowUI

Design system tokens and reusable UI components. Depends on LazyflowCore.

**Contents:**
- `DesignSystem.swift` — Spacing, typography, colors, corner radius tokens, button styles, badge components

```
Package: LazyflowUI
Platforms: iOS 17+, watchOS 10+
Dependencies: LazyflowCore
```

**Dependency graph:**
```
LazyflowCore → LazyflowUI → App / Widget / Watch
```

**Note:** Core Data entity extensions remain in the app target because SPM packages cannot reference `.xcdatamodeld` files.

## Architecture Patterns

### MVVM with @Observable

All ViewModels use the Swift `@Observable` macro (migrated from `ObservableObject` in v1.10):

```swift
@Observable
@MainActor
final class TodayViewModel {
    var tasks: [TaskItem] = []
    var isLoading = false

    private let taskService: any TaskServiceProtocol

    init(taskService: any TaskServiceProtocol = TaskService.shared) {
        self.taskService = taskService
    }
}
```

Views consume them with `@State` (not `@StateObject`):

```swift
struct TodayView: View {
    @State private var viewModel = TodayViewModel()
}
```

### Dependency Injection via Protocols

Services define protocols for testability:

| Protocol | Implementation | Purpose |
|----------|---------------|---------|
| `TaskServiceProtocol` | `TaskService` | Task CRUD, completion, ordering |
| `CalendarServiceProtocol` | `CalendarService` | EventKit read/write |
| `CategoryServiceProtocol` | `CategoryService` | Category management |
| `NotificationServiceProtocol` | `NotificationService` | Local notifications |
| `PersistenceControllerProtocol` | `PersistenceController` | Core Data stack |
| `LLMServiceProtocol` | `LLMService` | AI provider abstraction |

Production singletons via `static let shared`. Tests inject mock implementations through init parameters.

### Service Layer

Services are singletons managing specific domains:

- **TaskService** — Task CRUD, subtasks, completion tracking
- **CalendarService** — EventKit access, event creation
- **CalendarSyncService** — Two-way task↔event sync, dedicated Lazyflow calendar
- **PersistenceController** — Core Data stack, CloudKit container, migration
- **QuickNoteService** — Quick Capture note persistence and AI extraction
- **MetricsService** — MetricKit subscriber for performance/crash data
- **PrioritizationService** — AI-powered task ranking
- **DailySummaryService** — Morning Briefing and Daily Summary generation
- **NotificationService** — Local notification scheduling
- **LiveActivityManager** — Lock Screen Live Activity and Dynamic Island
- **AnalyticsService** — Local productivity analytics
- **WatchConnectivityService** — Apple Watch sync

### Feature Flags

Lightweight flag system with compile-time defaults and debug overrides:

```swift
@Observable
@MainActor
final class FeatureFlags {
    static let shared = FeatureFlags()

    enum Flag: String, CaseIterable {
        case quickCapture = "quick_capture"
        case focusMode = "focus_mode"
        case calendarSync = "calendar_sync"
        case morningBriefing = "morning_briefing"
        // ...
    }

    func isEnabled(_ flag: Flag) -> Bool
    func setOverride(_ flag: Flag, enabled: Bool)
    func removeOverride(_ flag: Flag)
}
```

Debug menu available in Settings for toggling flags at runtime. Overrides persist in UserDefaults.

### Structured Logging

All logging uses `os.Logger` with category-based subsystems (defined in `LazyflowCore/Extensions/Logger+Extensions.swift`):

```swift
extension Logger {
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let tasks = Logger(subsystem: subsystem, category: "tasks")
    static let calendar = Logger(subsystem: subsystem, category: "calendar")
    static let ai = Logger(subsystem: subsystem, category: "ai")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    // ...
}
```

Usage: `Logger.tasks.info("Task completed: \(task.title)")`. All `print()` calls were replaced in v1.10.

## Data Layer

### Core Data

- **Model:** `Lazyflow.xcdatamodeld` with lightweight migration support
- **Entities:** Task (with subtasks, scheduled times, recurring rules, calendar event links), QuickNote, Category, TaskList
- **Stack:** `PersistenceController` manages `NSPersistentCloudKitContainer`
- **Migration:** Hardened strategy with version detection, error handling, and fallback to clean store

### CloudKit Sync

- **Container:** `NSPersistentCloudKitContainer` for automatic iCloud sync
- **Conflict resolution:** Persistent history token tracking with merge policies
- **Monitoring:** Sync status observation for UI indicators

### Calendar Integration

- **Dedicated calendar:** Auto-created "Lazyflow" calendar in iCloud for synced events
- **Two-way sync:** Tasks with due dates + times auto-create calendar events; external event changes sync back
- **Recurring events:** Daily, weekly, biweekly, monthly, yearly recurring tasks create matching EventKit recurrence rules (intraday rules sync as one-off events)
- **Scheduled times:** Tasks can have explicit start/end times for event-like scheduling

## AI System

- **Default:** Apple Intelligence (on-device)
- **Optional:** Ollama (local) or custom providers (configurable in Settings)
- **Provider abstraction:** `LLMServiceProtocol` with pluggable implementations
- **Features:** Task prioritization, Morning Briefing generation, Daily Summary, Quick Capture task extraction, automatic categorization
- **Privacy:** On-device by default; external providers are opt-in with clear disclosure

## Testing

### Unit Tests (`LazyflowTests/`)
- Service logic, extensions, utilities
- Mock service implementations via DI protocols

### Snapshot Tests
- Key screens captured with fixed device size and locale
- Reference images stored in test target

### UI Tests (`LazyflowUITests/`)
- End-to-end automation on simulator
- Core user flows: add task, complete, navigate

## Localization

- **String Catalogs** (`.xcstrings`) for localization readiness
- All user-facing strings extracted for future translation
- Currently English-only

## Privacy & Security

- **PrivacyInfo.xcprivacy** — Privacy manifest declaring API usage
- **Data Protection** — Files encrypted when device is locked
- **Keychain** — Secure storage for sensitive configuration
- **No tracking, no analytics, no ads**

## Performance Monitoring

- **MetricKit** — `MetricsService` subscribes to `MXMetricManager` for CPU, memory, disk, and hang metrics
- **Crash diagnostics** — Automatic crash report collection via MetricKit

## View Architecture

Large views are split into focused files:

- **TodayView** → `TodayView.swift`, `TodayView+NextUp.swift`, `TodayView+Sections.swift`, plus sheets (`BatchRescheduleSheet`, `ConflictResolutionSheet`)
- **AddTaskView** → `AddTaskView.swift`, `AddTaskView+QuickActions.swift`, plus pickers (`DatePickerSheet`, `ListPickerSheet`)
- **SettingsView** → `SettingsView.swift`, `SettingsToggles.swift`, `AISettingsView.swift`, `NotificationSettingsView.swift`, `DataManagementView.swift`, `AboutView.swift`

## Build System

- **XcodeGen:** `project.yml` generates the Xcode project. Run `xcodegen generate` after adding/removing files.
- **CI:** GitHub Actions with build + unit test + coverage + UI test jobs
- **Dependencies:** Managed via SPM local packages (no external package dependencies)
