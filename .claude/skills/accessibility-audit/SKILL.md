---
disable-model-invocation: true
argument-hint: "[screen-name or 'full']"
description: "Accessibility audit — VoiceOver, Dynamic Type, color contrast, touch targets"
---

# Accessibility Audit

Systematic accessibility review for the Lazyflow iOS app. Argument can be a specific screen name (e.g. 'TodayView') or 'full' for a complete audit.

## Phase 1: Scope

### If specific screen:
1. Locate the View file
2. Identify all interactive elements (buttons, toggles, text fields, swipe actions)
3. Identify all informational elements (labels, icons, status indicators)

### If 'full' audit:
Audit all user-facing views in order of usage frequency:
1. TodayView (main screen)
2. TaskDetailView
3. CalendarView
4. ListsView
5. SettingsView
6. Quick Capture sheet
7. Focus Mode
8. Onboarding

## Phase 2: VoiceOver Audit

### Check accessibility labels
```bash
# Find interactive elements missing accessibility labels
grep -rn "Button\|Toggle\|TextField\|Slider\|Stepper\|Picker\|NavigationLink" Lazyflow/Sources/Views/ --include="*.swift" -l
```

For each interactive element, verify:
- [ ] Has `.accessibilityLabel()` (or meaningful text content that serves as label)
- [ ] Label describes the action, not the appearance (e.g., "Delete task" not "Red button")
- [ ] Icons without text have explicit labels
- [ ] Image-only buttons have accessibility labels

### Check accessibility traits
```bash
# Find trait usage
grep -rn "accessibilityAddTraits\|accessibilityTraits\|\.isButton\|\.isHeader" Lazyflow/Sources/Views/ --include="*.swift"
```

Verify:
- [ ] Section headers use `.accessibilityAddTraits(.isHeader)`
- [ ] Custom buttons use `.accessibilityAddTraits(.isButton)` (SwiftUI `Button` does this automatically)
- [ ] Selected/toggled items use `.accessibilityAddTraits(.isSelected)`
- [ ] Links use `.accessibilityAddTraits(.isLink)`
- [ ] Images use `.accessibilityAddTraits(.isImage)` or are hidden with `.accessibilityHidden(true)` if decorative

### Check reading order
- [ ] VoiceOver navigates elements in logical order (top-to-bottom, left-to-right)
- [ ] Grouped elements use `.accessibilityElement(children: .combine)` or `.accessibilityElement(children: .contain)`
- [ ] Custom sort order via `.accessibilitySortPriority()` where needed

### Check custom actions
- [ ] Swipe-to-delete has `.accessibilityAction(.delete)`
- [ ] Drag-to-reorder has appropriate accessibility actions
- [ ] Long-press menus have `.accessibilityAction(named:)` alternatives
- [ ] Custom gestures have accessibility equivalents

### Check hints
- [ ] Non-obvious actions have `.accessibilityHint()` (e.g., "Double tap to mark as complete")
- [ ] Hints describe the result, not the gesture
- [ ] Don't over-use hints on obvious actions (standard buttons don't need them)

## Phase 3: Dynamic Type

### Check typography usage
```bash
# Find hardcoded font sizes
grep -rn "\.font(.system(size:" Lazyflow/Sources/Views/ --include="*.swift"
grep -rn "UIFont.systemFont(ofSize:" Lazyflow/Sources/ --include="*.swift"
```

Verify:
- [ ] All text uses `DesignSystem.Typography` tokens (which map to system text styles)
- [ ] No hardcoded `Font.system(size:)` — use `.font(.body)`, `.font(.headline)`, etc.
- [ ] No fixed frame heights that would clip text at large sizes
- [ ] `ScrollView` wraps content that might overflow at large text sizes

### Check layout at extreme sizes
Test at these Dynamic Type sizes:
- **xSmall** — verify nothing looks awkwardly spaced
- **Default** — baseline
- **xxxLarge** — verify no truncation or overlap
- **AX5** (maximum accessibility size) — verify content is still usable

### Check truncation
- [ ] Long task titles truncate gracefully (`.lineLimit()` + `.truncationMode(.tail)`)
- [ ] Date/time labels don't overlap at large sizes
- [ ] Buttons remain tappable at all text sizes
- [ ] Tab bar labels remain readable

## Phase 4: Color & Contrast

### Check contrast ratios
WCAG AA requirements:
- **Normal text** (< 18pt): contrast ratio >= 4.5:1
- **Large text** (>= 18pt or >= 14pt bold): contrast ratio >= 3:1
- **UI components** (icons, borders): contrast ratio >= 3:1

### Check semantic color usage
```bash
# Find hardcoded colors
grep -rn "Color(#\|Color(red:\|UIColor(red:\|\.init(hex:" Lazyflow/Sources/Views/ --include="*.swift"
```

Verify:
- [ ] Uses `Color.Lazyflow.*` semantic colors (not hardcoded hex values)
- [ ] Uses `Color.adaptiveBackground`, `Color.adaptiveSurface` for backgrounds
- [ ] `Color.Lazyflow.textPrimary` for main text, `.textSecondary` for secondary
- [ ] Error/success/warning states use semantic colors (`.error`, `.success`, `.warning`)

### Check color-only information
- [ ] Status indicators use icons + color (not color alone)
- [ ] Priority levels are distinguishable without color (use shapes or labels)
- [ ] Completed tasks have visual indicator beyond just color change (e.g., strikethrough)
- [ ] Calendar events are identifiable without relying solely on color coding

### Verify in both modes
```bash
# Switch appearance
xcrun simctl ui booted appearance light
xcrun simctl io booted screenshot /tmp/lazyflow-light.png

xcrun simctl ui booted appearance dark
xcrun simctl io booted screenshot /tmp/lazyflow-dark.png
```

- [ ] All text is readable in light mode
- [ ] All text is readable in dark mode
- [ ] Icons are visible in both modes
- [ ] Borders/separators are visible in both modes

## Phase 5: Touch Targets

### Check minimum sizes
Apple HIG minimum: **44x44 points** for all interactive elements.

```bash
# Find potentially small touch targets
grep -rn "\.frame(width:\|\.frame(height:" Lazyflow/Sources/Views/ --include="*.swift"
```

Verify:
- [ ] All buttons have at least 44pt tap area (use `.frame(minWidth: 44, minHeight: 44)` or padding)
- [ ] Checkbox/toggle areas are at least 44pt
- [ ] Close/dismiss buttons in sheets are at least 44pt
- [ ] Icon-only buttons have sufficient padding

### Check spacing between targets
- [ ] Adjacent tappable elements have sufficient spacing (>= 8pt gap)
- [ ] List rows have enough height for comfortable tapping
- [ ] Swipe actions don't interfere with normal scrolling
- [ ] No overlapping touch areas

### Check Button implementations
```bash
# Find custom tap gestures that might miss accessibility
grep -rn "\.onTapGesture\|\.gesture(TapGesture" Lazyflow/Sources/Views/ --include="*.swift"
```

- [ ] Prefer `Button` over `.onTapGesture` (Button provides accessibility for free)
- [ ] If using `.onTapGesture`, ensure accessibility label and traits are added manually

## Phase 6: Report Format

Organize findings into a structured report. This format is important because it gives the developer a clear, actionable checklist:

```
## Accessibility Audit Report: {ScreenName}

### Summary
- Total issues: X (P1: Y, P2: Z, P3: W)
- VoiceOver: X issues
- Dynamic Type: X issues
- Color Contrast: X issues
- Touch Targets: X issues

### Issues Table
| # | Category | Severity | File:Line | Issue | Fix |
|---|----------|----------|-----------|-------|-----|
| 1 | VoiceOver | P1 | TaskRowView.swift:42 | Missing label on checkbox | `.accessibilityLabel("Mark \(task.title) complete")` |
```

Use the project's `DesignSystem.TouchTarget.minimum` constant (44pt) when recommending touch target fixes — this references the existing design token rather than hardcoding a number.

For color contrast, reference `Color.Lazyflow.*` semantic colors and `Color.adaptiveBackground`/`Color.adaptiveSurface` from the project's design system.

### SwiftUI modifier patterns

**Add accessibility label:**
```swift
Button(action: deleteTask) {
    Image(systemName: "trash")
}
.accessibilityLabel("Delete task")
```

**Group elements:**
```swift
HStack {
    Image(systemName: "checkmark.circle")
    Text(task.title)
    Text(task.dueDate, style: .date)
}
.accessibilityElement(children: .combine)
```

**Add custom action:**
```swift
TaskRow(task: task)
    .accessibilityAction(named: "Complete") {
        viewModel.toggleComplete(task)
    }
    .accessibilityAction(named: "Delete") {
        viewModel.delete(task)
    }
```

**Minimum touch target:**
```swift
Button(action: action) {
    Image(systemName: "plus")
        .frame(width: 44, height: 44)
}
```

**Dynamic Type safe layout:**
```swift
// Use ViewThatFits for adaptive layouts
ViewThatFits {
    HStack { label; value }  // Preferred horizontal layout
    VStack(alignment: .leading) { label; value }  // Fallback for large text
}
```

### Add accessibility snapshot tests
```swift
func testTodayViewAccessibility() {
    let view = TodayView()
        .environment(\.managedObjectContext, testContext)
    assertAccessibilitySnapshot(of: view)
}
```

```bash
# Run accessibility snapshot tests
xcodebuild test -scheme Lazyflow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LazyflowTests/Snapshots
```

## Quick Reference

| Check | Tool/Method | Standard |
|-------|------------|----------|
| VoiceOver labels | Xcode Accessibility Inspector | All interactive elements labeled |
| Dynamic Type | Simulator > Settings > Accessibility | Usable at AX5 |
| Color contrast | WebAIM contrast checker | 4.5:1 (text), 3:1 (UI) |
| Touch targets | Xcode View Debugger | >= 44x44pt |
| Reading order | VoiceOver on device | Logical top-to-bottom |
| Reduce Motion | Simulator > Settings > Accessibility | Animations respect preference |
