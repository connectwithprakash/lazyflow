# Lazyflow

[![Version](https://img.shields.io/badge/version-1.10.0-blue.svg)](https://github.com/connectwithprakash/lazyflow/releases)
[![App Store](https://img.shields.io/badge/App_Store-Available-0D96F6.svg?logo=apple)](https://apps.apple.com/us/app/lazyflow/id6757427688)
[![iOS](https://img.shields.io/badge/iOS-17.0+-000000.svg?logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg?logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A free, open-source todo app for iOS with AI-powered planning, Pomodoro focus timer, and calendar integration.

<p align="center">
  <a href="https://apps.apple.com/us/app/lazyflow/id6757427688">
    <img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83" alt="Download on the App Store" height="50">
  </a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/connectwithprakash/lazyflow/main/docs/site/assets/screenshots/light/iphone/01-today-view.png" width="180" alt="Today View">
  <img src="https://raw.githubusercontent.com/connectwithprakash/lazyflow/main/docs/site/assets/screenshots/light/iphone/11-morning-briefing.png" width="180" alt="Morning Briefing">
  <img src="https://raw.githubusercontent.com/connectwithprakash/lazyflow/main/docs/site/assets/screenshots/light/iphone/03-ai-priority.png" width="180" alt="AI Priority">
  <img src="https://raw.githubusercontent.com/connectwithprakash/lazyflow/main/docs/site/assets/screenshots/light/iphone/30-pomodoro-timer.png" width="180" alt="Pomodoro Focus Timer">
</p>

## Why Lazyflow?

Most todo apps just store tasks. Lazyflow helps you **plan your day** — capture rough notes and let AI turn them into tasks, sync tasks with your calendar, focus on one thing at a time with Pomodoro timers, and track your productivity with daily summaries.

## Features

- **Quick Capture** - Jot down rough notes, AI extracts structured tasks with due dates and priorities
- **Focus Mode** - Immersive single-task experience with Pomodoro timer, subtasks panel, and session persistence
- **Calendar Sync** - Dedicated Lazyflow calendar with two-way task-event sync, scheduled start/end times
- **Next Up** - Single focused task suggestion that learns from your completion patterns
- **Plan Your Day** - Morning Briefing and Daily Summary with AI-generated insights and carryover
- **Works Everywhere** - iPhone, iPad, Apple Watch, widgets, Siri, and Live Activities
- **Privacy First** - AI runs on-device by default. No tracking, no analytics, no ads
- **100% Free** - No subscriptions, no premium tiers. Open source under MIT License

Learn more at [lazyflow.netlify.app](https://lazyflow.netlify.app)

## For Developers

### Requirements

- iOS 17.0+
- Xcode 15.0+

### Getting Started

```bash
git clone https://github.com/connectwithprakash/lazyflow.git
cd lazyflow
open Lazyflow.xcodeproj
```

### Tech Stack

- **UI**: SwiftUI
- **Data**: Core Data + CloudKit
- **Calendar**: EventKit
- **AI**: Apple Intelligence, Ollama, or custom providers

### Deployment

```bash
bundle install
make beta    # Deploy to TestFlight
make release # Deploy to App Store
```

See [deployment guide](docs/project/deployment.md) for setup details.

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Why Open Source?

| Principle | What It Means |
|-----------|---------------|
| **Useful First** | No dark patterns or engagement hacks |
| **Privacy First** | No tracking, no data collection |
| **Transparent** | See exactly how your data is handled |
| **Built to Last** | The app lives on regardless of development pace |

Read the full [PHILOSOPHY.md](PHILOSOPHY.md) for more on our principles.

## Support

If you find Lazyflow useful, consider supporting its development:

<a href="https://github.com/sponsors/connectwithprakash">
  <img src="https://img.shields.io/badge/GitHub_Sponsors-Support-ea4aaa?logo=github" alt="GitHub Sponsors">
</a>
<a href="https://buymeacoffee.com/connectwithprakash">
  <img src="https://img.shields.io/badge/Buy_Me_a_Coffee-Support-FFDD00?logo=buymeacoffee&logoColor=black" alt="Buy Me a Coffee">
</a>

## License

[MIT](LICENSE)
