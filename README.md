# Lazyflow

[![Version](https://img.shields.io/badge/version-1.4.0-blue.svg)](https://github.com/connectwithprakash/lazyflow/releases)
[![App Store](https://img.shields.io/badge/App_Store-Available-0D96F6.svg?logo=apple)](https://apps.apple.com/us/app/lazyflow/id6757427688)
[![iOS](https://img.shields.io/badge/iOS-17.0+-000000.svg?logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg?logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A free, open-source todo app for iOS that helps you plan your day with AI-powered task prioritization.

<p align="center">
  <a href="https://apps.apple.com/us/app/lazyflow/id6757427688">
    <img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83" alt="Download on the App Store" height="50">
  </a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/connectwithprakash/lazyflow/main/docs/site/assets/screenshots/light/iphone/01-today-view.png" width="180" alt="Today View">
  <img src="https://raw.githubusercontent.com/connectwithprakash/lazyflow/main/docs/site/assets/screenshots/light/iphone/02-daily-summary.png" width="180" alt="Daily Summary">
  <img src="https://raw.githubusercontent.com/connectwithprakash/lazyflow/main/docs/site/assets/screenshots/light/iphone/03-ai-priority.png" width="180" alt="AI Priority">
  <img src="https://raw.githubusercontent.com/connectwithprakash/lazyflow/main/docs/site/assets/screenshots/light/iphone/07-settings.png" width="180" alt="Settings">
</p>

## Why Lazyflow?

Most todo apps just store tasks. Lazyflow helps you **plan your day** by combining calendar with tasks, letting AI tell you what to work on next, and tracking your productivity with daily summaries.

## Features

- **AI Priority** - Ask "What should I do next?" and get recommendations with scores and reasoning
- **Calendar Integration** - View events alongside tasks, schedule tasks as time blocks
- **Daily Summary** - Track completion streaks and get AI-generated productivity insights
- **Works Everywhere** - iPhone, iPad, Apple Watch, widgets, Siri, and Live Activities
- **Privacy First** - Your data stays on your device. No tracking, no analytics
- **100% Free** - No ads, no subscriptions, no premium tiers

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
- **AI**: Apple Intelligence (on-device)

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

---

Built with [Claude Code](https://claude.ai/code)
