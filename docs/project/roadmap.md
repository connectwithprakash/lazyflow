# Lazyflow Roadmap

An AI-powered task companion that helps us plan our day.

## Vision

Calendar and tasks finally work together. Lazyflow helps us see when we're free, schedule tasks as time blocks, and let AI tell us what to work on next.

## Who It's For

Anyone who:
- Uses a calendar for meetings and appointments
- Wants to see tasks and calendar together
- Likes AI help with prioritization and "What should I do next?"
- Values protecting focus time for deep work

## Design Principles

1. **Simplicity** - Match Apple Reminders on essentials, don't bloat
2. **Calendar-first** - Tasks and calendar should feel like one experience
3. **Privacy-focused** - Local processing, user owns all data
4. **Accessible** - WCAG AAA compliant, VoiceOver support
5. **Native** - Deep Apple ecosystem integration

## Future Considerations

- Mac Catalyst app
- Team collaboration features
- Additional calendar integrations (Google, Outlook)
- Natural language task parsing ("Call mom tomorrow 3 PM")

## User Stories

### Time Blocking
> When I have a 2-hour task to focus on, I can drag it to a free calendar slot. It creates a calendar event so I protect that time from meetings.

### Smart Reschedule
> When a meeting is added during my focus time, the app suggests rescheduling lower-priority tasks. I review and approve, and my calendar updates automatically.

## Version History

### Shipped

- **v1.8.0**: Navigation restructure — 5-tab layout (Today, Calendar, Upcoming, Insights, Me) with profile-centric organization; Analytics dashboard with category completion rates, work-life balance tracking, and productivity insights
- **v1.9.0**: Focus Mode — full-screen immersive single-task experience with live timer and progress ring; Next Up — single focused task suggestion with state-dependent actions (Start/Pause, Focus, Later); Feedback-conditioned AI reranking that learns from task completion patterns; Daily Summary carryover; Timer fix preventing accumulated time loss on pause/resume (#221)

### Current & Upcoming

- **v1.10.0** (planned): Calendar & Capture — natural language task parsing, quick capture from anywhere, deeper calendar integration

See [CHANGELOG.md](../../CHANGELOG.md) for detailed release history.

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for how to contribute to this project.
