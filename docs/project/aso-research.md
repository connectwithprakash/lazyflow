# App Store Optimization Research

Last updated: v1.10 (March 2026)

## Keyword Strategy

### Field Constraints
- **Title**: "Lazyflow" (indexed automatically, don't repeat in keywords)
- **Subtitle**: 30 characters max (indexed, don't repeat in keywords)
- **Keywords**: 100 characters max, comma-separated, no spaces after commas

### Keyword Selection Rationale

| Keyword | Rationale |
|---------|-----------|
| `todo` | Core category, highest volume search term |
| `task manager` | High-intent compound term; Apple combines with "todo" for "todo task manager" |
| `calendar` | Signature feature, strong search volume |
| `productivity` | Broad category term, captures browsing users |
| `reminders` | Captures users searching for Apple Reminders alternatives |
| `schedule` | Maps to calendar scheduling and time blocking |
| `daily planner` | Maps to Morning Briefing / Plan Your Day |
| `free` | Critical — Lazyflow is free vs competitors charging $4-$14/mo |
| `checklist` | Common search term for simple task management |
| `pomodoro` | Maps to new Pomodoro timer in Focus Mode, high-intent keyword |

### Keywords Removed
| Keyword | Reason |
|---------|--------|
| `tasks` | Replaced with `task manager` (higher intent, Apple still indexes "tasks" from compound) |
| `gtd` | Niche methodology, low search volume |
| `organizer` | Redundant with `planner`, lower intent |
| `ai` | Already indexed from subtitle ("AI Planner"), no need to repeat |
| `planner` | Already indexed from subtitle, covered by `daily planner` compound |
| `focus timer` | Already indexed from subtitle ("Focus Timer"), no need to repeat |
| `to-do` | Likely normalized to `todo` by Apple's search, low marginal value |
| `habit` | Replaced by `pomodoro` (higher intent, maps to new feature) |

### Keywords Not Included (in title/subtitle already)
Apple's search algorithm combines terms across title, subtitle, and keyword fields for compound matching. Repeating subtitle terms in keywords wastes characters.

- "Lazyflow" — indexed from app name
- "AI", "Planner", "Focus", "Timer" — all indexed from subtitle

## Subtitle Strategy

**Previous (v1.9)**: `Calendar-First Todo App` (23 chars) — descriptive but generic, didn't differentiate
**Current (v1.10)**: `AI Planner & Focus Timer` (24 chars) — highlights two strongest differentiators

The subtitle is indexed by App Store Search, so it contributes additional keyword coverage. "Calendar" moves to the keyword field since it's a well-known feature but not the primary differentiator.

## Description Strategy

### Structure (ordered by differentiation strength)
1. **Hook** — Free + AI + privacy (unique combo)
2. **AI-Powered Productivity** — Strongest differentiator (moved from 3rd to 1st)
3. **Focus Mode** — New dedicated section (was buried in AI section)
4. **Calendar Integration** — Signature feature
5. **Task Management** — Table stakes (moved down)
6. **Siri / Widgets / Watch / iPad** — Platform features
7. **Privacy** — Trust signal
8. **Open Source** — Unique among competitors

### Key Changes from v1.9 Description
- Lead with free + AI + privacy hook (unique value prop)
- Quick Capture added as first bullet in AI section (headline v1.10 feature)
- Focus Mode expanded: Pomodoro mode, subtasks/notes panel, session persistence
- Calendar section rewritten: dedicated Lazyflow calendar, two-way sync, scheduled times, recurring event sync
- Stronger privacy language: "no subscriptions or cloud lock-in"
- Added "no ads" to privacy section

## Competitive Landscape

| App | Price | AI | Focus Timer | Open Source |
|-----|-------|----|-------------|-------------|
| Todoist | $4/mo | Limited | No | No |
| Things 3 | $10 one-time | No | No | No |
| TickTick | $3/mo | No | Yes (Pomo) | No |
| Any.do | $5/mo | AI assistant | No | No |
| **Lazyflow** | **Free** | **On-device AI** | **Yes** | **Yes (MIT)** |

Lazyflow's unique combination: free + on-device AI + focus timer + open source. No competitor offers all four.

## Promotional Text Strategy

The promotional text field (170 chars max) sits above the description and can be updated without a new app version. It should reflect the latest release highlights.

- **v1.9**: Focused on new features (Focus Mode, Next Up, Daily Summary)
- **v1.10**: Feature-focused — Quick Capture (headline), Pomodoro timer, two-way calendar sync, scheduled times
