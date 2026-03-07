---
disable-model-invocation: true
argument-hint: "[appstore|website|both] [light|dark|both]"
description: "Automated App Store and website screenshot generation"
---

# App Store & Website Screenshots

Automates screenshot capture for App Store submissions and the Lazyflow website.

## Execution Requirement

This skill requires EXECUTING commands, not just planning them. Actually run the simulator commands, capture screenshots, and save files. Do not produce a plan describing what to do — perform the actions.

## Directory Routing

- **App Store screenshots** → `docs/assets/screenshots/appstore/`
- **Website screenshots** → `docs/site/assets/screenshots/{light,dark}/`
- **Fastlane screenshots** → `./fastlane/screenshots/` (for App Store upload)

When the user specifies "website only" or "appstore only", save to the correct directory — don't save to both.

## Phase 1: Setup

### 1a. Boot Simulator
```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl list devices | grep "iPhone 17 Pro"
```

### 1b. Install Latest Build
```bash
# Build for simulator
xcodebuild build -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

# Find and install the .app
APP_PATH=$(xcodebuild build -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')
xcrun simctl install booted "$APP_PATH/Lazyflow.app"
```

### 1c. Seed Demo Data

The app uses `@AppStorage` backed by UserDefaults with bundle ID `com.lazyflow.app`. Key names are defined in `AppConstants.StorageKey`. After writing defaults, you MUST kill cfprefsd or the app will read stale cached values.

```bash
# 1. Kill app first
xcrun simctl terminate booted com.lazyflow.app 2>/dev/null || true

# 2. Find and kill the simulator's cfprefsd (NOT the host's!)
SIM_UDID=$(xcrun simctl list devices booted -j | python3 -c "import sys,json; devs=[d for r in json.load(sys.stdin)['devices'].values() for d in r if d['state']=='Booted']; print(devs[0]['udid'])" 2>/dev/null)
CFPREFSD_PID=$(pgrep -f "CoreSimulator/Devices/$SIM_UDID.*cfprefsd" 2>/dev/null)
[ -n "$CFPREFSD_PID" ] && kill -9 $CFPREFSD_PID

# 3. Write defaults using xcrun simctl spawn (writes to simulator, not host)
xcrun simctl spawn booted defaults write com.lazyflow.app hasSeenOnboarding -bool true
xcrun simctl spawn booted defaults write com.lazyflow.app lastPlanYourDayDate -float $(date +%s)
xcrun simctl spawn booted defaults write com.lazyflow.app appearanceMode -string "system"
# Add more defaults as needed for demo state

# 4. Relaunch app
xcrun simctl launch booted com.lazyflow.app
```

### 1d. Set Appearance
```bash
# Light mode
xcrun simctl ui booted appearance light

# Dark mode
xcrun simctl ui booted appearance dark
```

## Phase 2: Screenshot Capture

### Key Screens to Capture

| # | Screen | Navigation | Notes |
|---|--------|-----------|-------|
| 1 | Today (with tasks) | App launch | Show 3-5 tasks with varied priorities |
| 2 | Calendar view | Tab: Calendar | Show a week with events + tasks |
| 3 | Lists view | Tab: Lists | Show 2-3 lists with task counts |
| 4 | Quick Capture | Swipe down / FAB | Show the capture sheet |
| 5 | Plan Your Day | Prompt card on Today | Show AI suggestions |
| 6 | Focus Mode | Start focus on a task | Show timer ring |
| 7 | Settings | Tab: Settings | Show preferences |

### Capture Commands

```bash
# Create output directories
mkdir -p docs/assets/screenshots/appstore/{light,dark}
mkdir -p docs/site/assets/screenshots/{light,dark}

# Launch app
xcrun simctl launch booted com.lazyflow.app

# Wait for app to load
sleep 3

# Capture screenshot
xcrun simctl io booted screenshot docs/assets/screenshots/appstore/light/01-today.png

# Navigate to next screen (using idb or simctl)
/Users/prakash/Library/Python/3.9/bin/idb ui tap X Y  # Tap coordinates for tab
sleep 1

# Continue for each screen...
```

### For Each Screen
1. Navigate to the screen (tap tab bar, present sheet, etc.)
2. Wait for content to load: `sleep 2`
3. Capture: `xcrun simctl io booted screenshot {path}`
4. Repeat for both light and dark modes

## Phase 3: App Store Screenshots (1284x2778)

App Store requires specific sizes. iPhone 17 Pro simulator captures at device resolution.

### Existing App Store Screenshots
Current naming convention in `docs/assets/screenshots/appstore/`:
- `01-today-view.png`
- `02-next-up-progress.png`
- `03-focus-mode.png`
- `04-morning-briefing.png`
- `05-insights.png`
- `06-task-edit.png`
- `07-add-task.png`
- `08-ipad-today.png`
- `09-ipad-calendar.png`
- `10-ipad-lists.png`
- `11-watch-today.png`

```bash
# Set appearance and capture each screen
for MODE in light dark; do
    xcrun simctl ui booted appearance $MODE
    sleep 1

    # Relaunch app to pick up appearance
    xcrun simctl terminate booted com.lazyflow.app
    xcrun simctl launch booted com.lazyflow.app
    sleep 3

    # Capture Today
    xcrun simctl io booted screenshot "docs/assets/screenshots/appstore/$MODE/01-today-view.png"

    # Navigate and capture remaining screens...
done
```

## Phase 4: Website Screenshots

### Existing Website Screenshot Structure
Website screenshots are in `docs/site/assets/screenshots/` with subdirectories:
- `light/` and `dark/` — Numbered screenshots (01-28+)
- `light/iphone/` and `dark/iphone/` — iPhone-specific captures
- `ipad/` — iPad screenshots (light/dark variants)
- `watch/` — Watch screenshots
- `widgets/` — Widget screenshots (small/medium/large, light/dark)
- `live-activity/` — Dynamic Island and Lock Screen
- `launch/` — Launch screen phases

```bash
# Website screenshots use same captures but different naming
# Naming: {number}-{feature-name}.png
cp docs/assets/screenshots/appstore/light/01-today-view.png docs/site/assets/screenshots/light/01-today-view.png
cp docs/assets/screenshots/appstore/dark/01-today-view.png docs/site/assets/screenshots/dark/01-today-view.png
# ... repeat for all screens
```

## Phase 5: Post-Processing

### Verify
```bash
# List all captured screenshots
ls -la docs/assets/screenshots/appstore/light/
ls -la docs/assets/screenshots/appstore/dark/
ls -la docs/site/assets/screenshots/light/
ls -la docs/site/assets/screenshots/dark/
```

### Upload to App Store (L3 — user-initiated only)
```bash
# Only after user approval
# Screenshots path for fastlane: ./fastlane/screenshots
bundle exec fastlane upload_screenshots
```

### Update Website (L3 — user-initiated only)
```bash
# Update design gallery page
# Edit docs/site/design/index.html to reference new screenshots
# Deploy: netlify deploy --prod --dir=docs/site
```

## Checklist

- [ ] All key screens captured
- [ ] Both light and dark mode
- [ ] Demo data looks realistic (not "Test Task 1")
- [ ] No personal data visible in screenshots
- [ ] Screenshots match current UI (not stale)
- [ ] App Store screenshots at correct resolution
- [ ] Website screenshots saved with correct naming convention
- [ ] User notified about design gallery update
- [ ] User notified about Fastlane upload option

## Tips

- **@AppStorage changes**: After `defaults write`, kill simulator cfprefsd and relaunch app
- **idb coordinates**: Use `idb ui describe-all` to find element positions
- **Status bar**: Simulator shows realistic status bar (time, signal, battery)
- **Clean state**: Use `xcrun simctl erase "iPhone 17 Pro"` for a completely clean start (destructive!)
- **Fastlane screenshots path**: `./fastlane/screenshots` (used by `upload_screenshots` lane)
- **App Store upload**: Fastlane uses `deliver` with `overwrite_screenshots: true`
