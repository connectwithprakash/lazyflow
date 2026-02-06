# Issue #130: Category and List Analytics in Insights Tab

## Overview

This document expands on GitHub Issue #130 to provide comprehensive documentation for implementing category and list analytics within the Insights tab of Lazyflow. The goal is to transform raw task data into actionable productivity insights that help users understand their behavior patterns and make informed decisions about how they allocate their time and energy.

## Table of Contents

1. [Productivity Science Foundation](#1-productivity-science-foundation)
2. [Metrics That Matter](#2-metrics-that-matter)
3. [Visualization Strategy](#3-visualization-strategy)
4. [Category Insights](#4-category-insights)
5. [List/Project Insights](#5-listproject-insights)
6. [Combined Insights](#6-combined-insights)
7. [Actionable Recommendations](#7-actionable-recommendations)
8. [Time-Based Analysis](#8-time-based-analysis)
9. [Gamification & Motivation](#9-gamification--motivation)
10. [Technical Implementation](#10-technical-implementation)
11. [Industry Analysis](#11-industry-analysis)
12. [Data Model Extensions](#12-data-model-extensions)
13. [UI/UX Specifications](#13-uiux-specifications)
14. [Accessibility Requirements](#14-accessibility-requirements)
15. [Testing Strategy](#15-testing-strategy)

---

## 1. Productivity Science Foundation

### 1.1 Research-Backed Principles

Modern productivity research emphasizes a shift from activity-based metrics to outcome-based measurement. Key findings that inform our analytics design:

**Productivity+ Model**: Organizations must move beyond one-dimensional productivity measures to integrate output with purpose, well-being, and culture. Pure productivity metrics capture quantity but miss quality, creativity, and long-term impact.

**Work-Rest Balance Research**: Studies show top achievers work approximately 75 minutes followed by 33 minutes of rest. This informs our time blocking recommendations and focus session design.

**Focus Efficiency**: Research indicates focus efficiency decreases to 62% with excessive multitasking and collaboration overload. Our analytics should identify patterns that may indicate focus fragmentation.

**Well-being Correlation**: 70% of employees maintaining healthy work patterns show the highest productivity levels in three years, demonstrating that sustainable productivity requires balance.

### 1.2 Work-Life Balance Measurement

Work-life balance research identifies three core dimensions we should measure:

| Dimension | Description | Lazyflow Proxy |
|-----------|-------------|----------------|
| **Work Interference with Personal Life (WIPL)** | Work obligations bleeding into personal time | Work category tasks scheduled outside working hours |
| **Personal Life Interference with Work (PLIW)** | Personal matters disrupting work | Personal category tasks during work hours |
| **Work-Personal Life Enhancement (WPLE)** | Positive spillover between domains | Completion of both work and personal goals |

**Key Indicators**:
- Time distribution ratio (target: 60% Work / 40% Life or user-defined)
- Category completion equity (all categories should have reasonable completion rates)
- Off-hours task activity (warning if excessive)
- Neglected category detection (categories with < 30% completion rate)

### 1.3 Avoiding Vanity Metrics

**Vanity Metrics** (avoid emphasizing):
- Total tasks created (encourages task inflation)
- Absolute task counts without context
- Raw time logged without quality consideration
- Comparisons that encourage unhealthy competition

**Actionable Metrics** (prioritize):
- Completion rate by category (reveals neglected areas)
- Estimation accuracy (improves planning)
- Overdue task trends (identifies systemic issues)
- Category balance shifts (tracks behavioral change)
- High-priority task completion rate (measures effectiveness)

---

## 2. Metrics That Matter

### 2.1 Core Metrics Hierarchy

```
Tier 1: Essential (Always Visible)
├── Completion Rate by Category
├── Work-Life Balance Score
└── Weekly Task Completion Trend

Tier 2: Diagnostic (Expandable)
├── Estimation Accuracy
├── Overdue Task Rate by Category
├── Peak Productivity Times
└── Project Velocity

Tier 3: Deep Insights (On Demand)
├── Category Correlation Analysis
├── Seasonal Patterns
├── List Health Scores
└── Predictive Capacity
```

### 2.2 Metric Formulas

#### Completion Rate by Category
```
CategoryCompletionRate(c) = CompletedTasks(c) / TotalTasks(c) * 100

Where:
- c = specific category
- TotalTasks includes tasks created within the time period
- CompletedTasks includes tasks completed within the time period
```

#### Work-Life Balance Score
```
WLBScore = 100 - |ActualRatio - TargetRatio| * 100

Where:
- ActualRatio = WorkCategoryTime / TotalCategorizedTime
- TargetRatio = UserDefinedTarget (default: 0.6)
- Score of 100 = perfect balance
- Score decreases as deviation increases
```

#### Estimation Accuracy
```
EstimationAccuracy = 1 - (|ActualDuration - EstimatedDuration| / EstimatedDuration)

Aggregated:
OverallAccuracy = AVG(EstimationAccuracy) for tasks with both estimated and actual durations
```

#### Project Velocity
```
Velocity(list, period) = CompletedTasks(list) / DaysInPeriod

TrendDirection = Velocity(current_period) - Velocity(previous_period)
```

#### List Health Score
```
HealthScore = w1*CompletionRate + w2*(1-OverdueRate) + w3*ActivityRecency + w4*VelocityStability

Where:
- w1 = 0.35 (completion rate weight)
- w2 = 0.25 (overdue penalty weight)
- w3 = 0.20 (recency weight)
- w4 = 0.20 (stability weight)
- ActivityRecency = 1 - (DaysSinceLastUpdate / 30), min 0
- VelocityStability = 1 - StandardDeviation(weekly_velocities) / Mean(weekly_velocities)
```

#### Stale List Detection
```
IsStale(list) = TRUE if:
- No activity in 14+ days AND
- Has incomplete tasks AND
- Not marked as "on hold"

StalenessLevel:
- Warning: 14-30 days inactive
- Critical: 30+ days inactive
```

---

## 3. Visualization Strategy

### 3.1 Chart Type Selection Matrix

| Data Type | Recommended Chart | Alternative | Avoid |
|-----------|-------------------|-------------|-------|
| Category distribution | Donut chart | Horizontal bar | Pie (> 6 slices) |
| Trend over time | Line chart | Area chart | Pie chart |
| Comparison (few items) | Horizontal bar | Grouped bar | Stacked bar |
| Part-to-whole | Donut/Ring | Treemap | 3D pie |
| Time patterns | Heat map | Small multiples | Line (too many series) |
| Progress | Progress ring | Linear gauge | Pie chart |
| Correlation | Scatter plot | Connected scatter | Bar chart |

### 3.2 Mobile-First Chart Design

**Constraints**:
- Screen width: 320-428pt (iPhone SE to iPhone Pro Max)
- Touch target minimum: 44pt
- Readable text minimum: 11pt
- Optimal chart height: 200-280pt

**Design Principles**:

1. **Horizontal Orientation for Labels**: Use horizontal bar charts when category names are long
2. **Limited Data Points**: Max 6-8 visible data points; aggregate others as "Other"
3. **Interactive Exploration**: Tap to reveal details rather than cramming information
4. **Consistent Color Mapping**: Categories always use the same color across all charts

```
┌─────────────────────────────────────────────┐
│  Category Distribution                      │
│  ─────────────────────────────────────────  │
│                                             │
│     ┌─────────────────────────┐             │
│     │         Work            │ 45%         │
│     │        ┌────────┐       │             │
│     │        │ Donut  │       │             │
│     │        │ Chart  │       │             │
│     │        │        │       │             │
│     │        └────────┘       │             │
│     │   Personal    Health    │             │
│     │     25%         15%     │             │
│     └─────────────────────────┘             │
│                                             │
│  Legend (tap to filter):                    │
│  [■ Work] [■ Personal] [■ Health] [+3]      │
│                                             │
└─────────────────────────────────────────────┘
```

### 3.3 Swift Charts Implementation Patterns

```swift
// Donut Chart for Category Distribution
Chart(categoryData) { item in
    SectorMark(
        angle: .value("Tasks", item.count),
        innerRadius: .ratio(0.618), // Golden ratio
        angularInset: 1.5
    )
    .foregroundStyle(by: .value("Category", item.category.displayName))
    .cornerRadius(4)
}
.chartLegend(position: .bottom, spacing: 12)
.frame(height: 240)

// Line Chart for Trends
Chart(trendData) { point in
    LineMark(
        x: .value("Date", point.date),
        y: .value("Completed", point.completed)
    )
    .symbol(Circle())
    .interpolationMethod(.catmullRom)

    AreaMark(
        x: .value("Date", point.date),
        y: .value("Completed", point.completed)
    )
    .foregroundStyle(
        .linearGradient(
            colors: [.accent.opacity(0.3), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}
.chartXAxis {
    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
    }
}
```

### 3.4 Accessibility for Colorblind Users

**Color Palette (Colorblind-Safe)**:

| Category | Default Color | Deuteranopia Safe | Pattern Backup |
|----------|---------------|-------------------|----------------|
| Work | Blue #007AFF | Blue #0077BB | Solid |
| Personal | Purple #AF52DE | Purple #882255 | Horizontal lines |
| Health | Green #34C759 | Teal #009988 | Diagonal lines |
| Finance | Mint #00C7BE | Cyan #33BBEE | Dots |
| Shopping | Orange #FF9500 | Orange #EE7733 | Crosshatch |
| Errands | Yellow #FFCC00 | Yellow #CCBB44 | Vertical lines |
| Learning | Cyan #5AC8FA | Light Blue #0099CC | Dashes |
| Home | Brown #A2845E | Brown #AA4499 | Zigzag |

**Implementation Requirements**:

1. **Never rely on color alone**: Add patterns, icons, or labels
2. **Test with iOS Accessibility > Color Filters**: Simulate protanopia/deuteranopia
3. **Minimum contrast ratio**: 3:1 for graphical objects (WCAG 2.1 Level AA)
4. **VoiceOver descriptions**: Include percentage and absolute values

```swift
// Accessible chart with patterns
SectorMark(...)
    .foregroundStyle(by: .value("Category", item.category))
    .accessibilityLabel("\(item.category.displayName)")
    .accessibilityValue("\(item.count) tasks, \(item.percentage)%")
```

### 3.5 Heat Map Design for Time Patterns

```
┌─────────────────────────────────────────────┐
│  Productivity by Day & Time                 │
│  ─────────────────────────────────────────  │
│                                             │
│        Mon  Tue  Wed  Thu  Fri  Sat  Sun    │
│  6 AM  [ ]  [ ]  [ ]  [ ]  [ ]  [ ]  [ ]    │
│  9 AM  [██] [██] [██] [██] [██] [ ]  [ ]    │
│ 12 PM  [█ ] [██] [█ ] [██] [█ ] [ ]  [ ]    │
│  3 PM  [██] [█ ] [██] [█ ] [██] [ ]  [ ]    │
│  6 PM  [█ ] [█ ] [█ ] [█ ] [█ ] [ ]  [ ]    │
│  9 PM  [ ]  [ ]  [ ]  [ ]  [ ]  [ ]  [ ]    │
│                                             │
│  [ ] 0   [█ ] 1-3   [██] 4+  tasks/hour     │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 4. Category Insights

### 4.1 Time Distribution View

**Primary Visualization**: Donut chart with center stat

```
┌─────────────────────────────────────────────┐
│  Time by Category                  This Week │
│  ─────────────────────────────────────────  │
│                                             │
│            ┌──────────────┐                 │
│           /    Work       \                 │
│          │   ┌──────┐     │                 │
│    Home  │   │ 12.5 │     │  Personal       │
│          │   │hours │     │                 │
│           \   └──────┘   /                  │
│            └──────────────┘                 │
│           Health    Finance                 │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ Work      ████████████████  45% 5.6h │   │
│  │ Personal  ████████         25% 3.1h │   │
│  │ Health    █████            15% 1.9h │   │
│  │ Home      ███               8% 1.0h │   │
│  │ Other     ██                7% 0.9h │   │
│  └─────────────────────────────────────┘    │
│                                             │
└─────────────────────────────────────────────┘
```

**Time Calculation**:
- Use `estimatedDuration` for incomplete tasks
- Use `accumulatedDuration` for completed tasks with time tracking
- Fall back to `estimatedDuration` for completed tasks without tracking

### 4.2 Completion Rates by Category

**Primary Visualization**: Horizontal bar chart with benchmark line

```
┌─────────────────────────────────────────────┐
│  Completion Rate by Category                │
│  ─────────────────────────────────────────  │
│                                   Target 70% │
│                                       │      │
│  Work      ███████████████████████│██ 82%   │
│  Personal  █████████████████████  │   71%   │
│  Finance   ████████████████       │   58%   │
│  Health    █████████              │   35%   │ ⚠
│  Shopping  ██████████████████████ │   75%   │
│                                             │
│  ⚠ Health tasks need attention              │
│                                             │
└─────────────────────────────────────────────┘
```

### 4.3 Work-Life Balance Indicator

**Primary Visualization**: Balance gauge

```
┌─────────────────────────────────────────────┐
│  Work-Life Balance                          │
│  ─────────────────────────────────────────  │
│                                             │
│              Work          Life             │
│                                             │
│    ◄─────────[■■■■■■│░░░░]──────────►       │
│              62%    │   38%                 │
│                     │                       │
│              Target: 60/40                  │
│                                             │
│  Status: ✓ Well balanced                    │
│                                             │
│  Work: Work, Finance, Learning              │
│  Life: Personal, Health, Shopping,          │
│        Errands, Home                        │
│                                             │
└─────────────────────────────────────────────┘
```

**Category Classification**:
- Work Life: Work, Finance, Learning
- Personal Life: Personal, Health, Shopping, Errands, Home
- User can customize this mapping in Settings

### 4.4 Category Trends Over Time

**Primary Visualization**: Stacked area chart

```
┌─────────────────────────────────────────────┐
│  Category Trends                            │
│  ─────────────────────────────────────────  │
│                                             │
│  ▲                                          │
│  │    ╱────╲                                │
│  │ ╱─╱ Work ╲─╲                             │
│  │╱ Personal  ╲╲                            │
│  │  Health      ╲──────                     │
│  └──────────────────────────────────►       │
│    W1    W2    W3    W4    W5    W6         │
│                                             │
│  Insight: Work tasks increased 23% this     │
│  month while Health tasks decreased 15%     │
│                                             │
└─────────────────────────────────────────────┘
```

### 4.5 Best Times by Category

**Primary Visualization**: Small multiples heat maps

```
┌─────────────────────────────────────────────┐
│  Peak Productivity by Category              │
│  ─────────────────────────────────────────  │
│                                             │
│  Work               Personal                │
│  ┌─────────────┐    ┌─────────────┐         │
│  │    M T W T F│    │    M T W T F│         │
│  │ AM ██████   │    │ AM          │         │
│  │ PM ████     │    │ PM ██████   │         │
│  │ EV          │    │ EV ████████ │         │
│  └─────────────┘    └─────────────┘         │
│  Peak: 9-11 AM      Peak: 6-8 PM            │
│                                             │
│  Health             Finance                 │
│  ┌─────────────┐    ┌─────────────┐         │
│  │    M T W T F│    │    M T W T F│         │
│  │ AM ████████ │    │ AM          │         │
│  │ PM          │    │ PM ████     │         │
│  │ EV ██       │    │ EV          │         │
│  └─────────────┘    └─────────────┘         │
│  Peak: 6-8 AM       Peak: 2-4 PM Fri        │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 5. List/Project Insights

### 5.1 Project Velocity Dashboard

**Primary Visualization**: Sparkline-enhanced list

```
┌─────────────────────────────────────────────┐
│  Project Velocity                           │
│  ─────────────────────────────────────────  │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ ■ Work Projects        ╱╲╱╲╱╱╲_    │    │
│  │   12 tasks/week         ▲ +20%      │    │
│  │   23/45 complete (51%)              │    │
│  ├─────────────────────────────────────┤    │
│  │ ● Home Renovation      ─╱╲─╲_      │    │
│  │   3 tasks/week          ▼ -15%      │    │
│  │   8/20 complete (40%)               │    │
│  ├─────────────────────────────────────┤    │
│  │ ▲ Side Project         ╱╱╱╱╱╱╱     │    │
│  │   8 tasks/week          ▲ +45%      │    │
│  │   15/25 complete (60%)              │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  Sparkline = last 6 weeks velocity          │
│                                             │
└─────────────────────────────────────────────┘
```

### 5.2 List Health Matrix

**Primary Visualization**: Grid with health indicators

```
┌─────────────────────────────────────────────┐
│  List Health Overview                       │
│  ─────────────────────────────────────────  │
│                                             │
│  ┌──────────┬─────────┬─────────┬─────────┐ │
│  │   List   │ Health  │ Overdue │ Velocity│ │
│  ├──────────┼─────────┼─────────┼─────────┤ │
│  │ Inbox    │ ●●●○○   │    2    │  Stable │ │
│  │ Work     │ ●●●●●   │    0    │    ▲    │ │
│  │ Personal │ ●●●●○   │    1    │  Stable │ │
│  │ Home     │ ●●○○○   │    5    │    ▼    │ │
│  │ Learning │ ●○○○○   │    8    │ Stalled │ │
│  └──────────┴─────────┴─────────┴─────────┘ │
│                                             │
│  ⚠ Learning has 8 overdue tasks             │
│  ⚠ Home health score declining              │
│                                             │
└─────────────────────────────────────────────┘
```

### 5.3 Stale List Detection

**Alert Card Design**:

```
┌─────────────────────────────────────────────┐
│  ⚠️ Stale Projects Detected                  │
│  ─────────────────────────────────────────  │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ 📚 Learn Spanish                    │    │
│  │ Last activity: 32 days ago          │    │
│  │ 12 tasks remaining                  │    │
│  │                                     │    │
│  │ [Archive]  [Snooze]  [Tackle Now]   │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ 🏠 Garage Organization              │    │
│  │ Last activity: 21 days ago          │    │
│  │ 5 tasks remaining                   │    │
│  │                                     │    │
│  │ [Archive]  [Snooze]  [Tackle Now]   │    │
│  └─────────────────────────────────────┘    │
│                                             │
└─────────────────────────────────────────────┘
```

### 5.4 Overdue Tasks by List

**Primary Visualization**: Horizontal bar chart with urgency encoding

```
┌─────────────────────────────────────────────┐
│  Overdue by Project                         │
│  ─────────────────────────────────────────  │
│                                             │
│  Learning    █████████████████  8 tasks     │
│              ▓▓▓▓▓▓▓▓▓░░░░░░░               │
│              5 urgent  3 normal             │
│                                             │
│  Home        █████████  5 tasks             │
│              ▓▓▓░░░░░░                      │
│              2 urgent  3 normal             │
│                                             │
│  Inbox       ████  2 tasks                  │
│              ░░░░                           │
│              0 urgent  2 normal             │
│                                             │
│  Total overdue: 15 tasks                    │
│                                             │
└─────────────────────────────────────────────┘
```

### 5.5 List Completion Trends

**Primary Visualization**: Line chart with completion rate overlay

```
┌─────────────────────────────────────────────┐
│  Work Projects - Completion Trend           │
│  ─────────────────────────────────────────  │
│                                             │
│  ▲ 100%                                     │
│  │       ●                     ●            │
│  │      ╱ ╲                   ╱             │
│  │     ╱   ╲     ●           ╱              │
│  │    ╱     ╲   ╱ ╲         ╱               │
│  │   ●       ╲ ╱   ╲       ╱                │
│  │            ●     ╲     ●                 │
│  │                   ╲   ╱                  │
│  │                    ●                     │
│  └──────────────────────────────────────►   │
│    Jan  Feb  Mar  Apr  May  Jun             │
│                                             │
│  Average: 72%  │  Trend: ▲ Improving        │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 6. Combined Insights

### 6.1 Category Performance Within Lists

**Primary Visualization**: Grouped bar chart or matrix

```
┌─────────────────────────────────────────────┐
│  Category Performance by List               │
│  ─────────────────────────────────────────  │
│                                             │
│           Work  Personal  Health  Other     │
│           ────  ────────  ──────  ─────     │
│  Inbox    85%     72%      45%     68%      │
│  Work     92%     --       --      75%      │
│  Personal --      78%      52%     70%      │
│  Home     --      80%      --      65%      │
│                                             │
│  🔍 Insight: Health tasks have lowest       │
│  completion rates regardless of list.       │
│  Consider scheduling dedicated health       │
│  time blocks.                               │
│                                             │
└─────────────────────────────────────────────┘
```

### 6.2 Pattern Detection

**Detected Pattern Examples**:

```
┌─────────────────────────────────────────────┐
│  📊 Pattern Insights                        │
│  ─────────────────────────────────────────  │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ 💡 Health Task Pattern              │    │
│  │                                     │    │
│  │ Health tasks without a specific     │    │
│  │ list have 35% completion rate.      │    │
│  │ Those in "Fitness Goals" list:      │    │
│  │ 68% completion rate.                │    │
│  │                                     │    │
│  │ Suggestion: Create a dedicated      │    │
│  │ health list with reminders.         │    │
│  │                                     │    │
│  │ [Create Health List]                │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ 📈 Work Efficiency Pattern          │    │
│  │                                     │    │
│  │ Work tasks completed in morning     │    │
│  │ are 2.3x more likely to be done     │    │
│  │ on time than afternoon tasks.       │    │
│  │                                     │    │
│  │ Your most productive Work hours:    │    │
│  │ 9 AM - 11 AM                        │    │
│  └─────────────────────────────────────┘    │
│                                             │
└─────────────────────────────────────────────┘
```

### 6.3 Correlation Matrix

**Advanced Analysis** (accessible via "Deep Insights"):

```
┌─────────────────────────────────────────────┐
│  Category Correlations                      │
│  ─────────────────────────────────────────  │
│                                             │
│  When Work completion is HIGH:              │
│  • Personal completion ↓ 12%                │
│  • Health completion ↓ 25%                  │
│  • Finance completion → stable              │
│                                             │
│  When Health completion is HIGH:            │
│  • Work completion ↑ 8%                     │
│  • Personal completion ↑ 15%                │
│  • Overall mood score ↑ 20%                 │
│                                             │
│  💡 Maintaining health tasks seems to       │
│  positively impact other categories.        │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 7. Actionable Recommendations

### 7.1 Recommendation Engine Logic

```swift
enum InsightType {
    case warning      // Needs immediate attention
    case suggestion   // Improvement opportunity
    case celebration  // Positive reinforcement
    case trend        // Notable pattern
}

struct Insight {
    let type: InsightType
    let title: String
    let description: String
    let category: TaskCategory?
    let list: TaskList?
    let action: InsightAction?
    let priority: Int // 1-10, higher = more important
}

enum InsightAction {
    case createList(suggestedName: String, category: TaskCategory)
    case scheduleTimeBlock(category: TaskCategory, suggestedTime: TimeSlot)
    case reviewOverdue(list: TaskList)
    case archiveStale(list: TaskList)
    case adjustBalance(targetRatio: Double)
    case setReminder(category: TaskCategory)
}
```

### 7.2 Insight Generation Rules

| Condition | Insight | Priority |
|-----------|---------|----------|
| Category completion < 40% | "Your {category} tasks need attention. Only {rate}% completed this week." | 8 |
| Category completion dropped > 20% | "Your {category} completion rate dropped {amount}%. Need help catching up?" | 7 |
| List overdue > 5 tasks | "You have {count} overdue tasks in {list}. Review and reschedule?" | 9 |
| List inactive > 14 days | "Haven't touched {list} in {days} days. Archive or tackle it?" | 6 |
| Work-life ratio > 75% work | "Heavy work focus this week ({ratio}%). Remember to balance with personal time." | 5 |
| Streak milestone | "Amazing! {days}-day streak! You've completed tasks every day." | 3 |
| Category completion > 90% | "Crushing it on {category}! {rate}% completion rate this week." | 2 |
| Estimation accuracy improved | "Your time estimates are getting better! {accuracy}% accurate now." | 4 |

### 7.3 Nudge vs Report Strategy

**Nudges** (Proactive, contextual):
- Appear at relevant moments (morning briefing, end of day)
- Limited to 1-2 per day to avoid notification fatigue
- Actionable with single-tap responses
- Can be dismissed or snoozed

**Reports** (On-demand, comprehensive):
- Weekly summary email/notification (optional)
- Full Insights tab exploration
- Historical trend analysis
- Detailed breakdowns

**Nudge Timing Rules**:
```
Morning (8-9 AM):
- Today's priority category hint
- Overdue task reminder if > 3 tasks

End of Day (6-7 PM):
- Daily summary prompt if > 5 tasks completed
- Balance check if worked > 8 hours

Weekly (Sunday evening):
- Week in review prompt
- Next week planning suggestion
```

### 7.4 Sample Insight Cards

```
┌─────────────────────────────────────────────┐
│  ⚠️ Health Tasks Need Attention             │
│  ─────────────────────────────────────────  │
│                                             │
│  You complete 82% of Work tasks but only    │
│  35% of Health tasks.                       │
│                                             │
│  Quick wins to try:                         │
│  • Schedule 30-min morning health block     │
│  • Set daily health task reminders          │
│  • Link health tasks to calendar events     │
│                                             │
│  [Schedule Health Time]  [Remind Me Later]  │
│                                             │
└─────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────┐
│  🎉 Great Week for Work!                    │
│  ─────────────────────────────────────────  │
│                                             │
│  You completed 23 Work tasks this week,     │
│  your highest ever!                         │
│                                             │
│  Peak productivity: Tuesday 9-11 AM         │
│  Most productive project: Q1 Planning       │
│                                             │
│  Keep protecting those morning hours.       │
│                                             │
│  [Share Achievement]  [View Details]        │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 8. Time-Based Analysis

### 8.1 Time Range Selector

```
┌─────────────────────────────────────────────┐
│  ┌─────┬───────┬─────────┬───────────────┐  │
│  │ Day │ Week  │  Month  │   Quarter     │  │
│  └─────┴───────┴─────────┴───────────────┘  │
│          ▲ selected                         │
│                                             │
│  ◄  Jan 27 - Feb 2, 2025  ►                 │
│                                             │
└─────────────────────────────────────────────┘
```

**Available Views**:
- **Day**: Hour-by-hour breakdown, good for deep analysis
- **Week**: Default view, balanced detail vs overview
- **Month**: Trend identification, pattern recognition
- **Quarter**: Long-term habit tracking, seasonal patterns

### 8.2 Trend Detection Algorithm

```swift
struct TrendAnalysis {
    enum Direction {
        case increasing
        case decreasing
        case stable
    }

    let direction: Direction
    let changePercent: Double
    let confidence: Double // 0-1, based on data points and variance

    static func analyze(dataPoints: [Double]) -> TrendAnalysis {
        // Linear regression for direction
        // Calculate slope and R² for confidence
        // Use rolling average to smooth noise
    }
}

// Trend thresholds:
// - Increasing/Decreasing: |change| > 10% AND confidence > 0.6
// - Stable: |change| <= 10% OR confidence <= 0.6
```

### 8.3 Seasonality Detection

**Weekly Patterns**:
```
Monday:    High task creation, moderate completion
Tuesday:   Peak completion day
Wednesday: Moderate all around
Thursday:  Completion drops, meeting heavy
Friday:    Low creation, high completion (cleanup)
Weekend:   Personal tasks dominate
```

**Monthly Patterns**:
```
Week 1:    Planning heavy, goal setting
Week 2-3:  Execution phase, highest velocity
Week 4:    Review, wrap-up, lower creation
```

**Visualization**: Small multiples by day/week

### 8.4 Historical Goal Setting

```
┌─────────────────────────────────────────────┐
│  Set Weekly Goal                            │
│  ─────────────────────────────────────────  │
│                                             │
│  Based on your history:                     │
│  • Average: 18 tasks/week                   │
│  • Best week: 27 tasks                      │
│  • Typical range: 14-22 tasks               │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │      ◄───[███████░░░]───►           │    │
│  │            20 tasks                 │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  Suggested: 20 tasks (challenging but       │
│  achievable based on your patterns)         │
│                                             │
│  [Set Goal]                                 │
│                                             │
└─────────────────────────────────────────────┘
```

### 8.5 Compare Periods

```
┌─────────────────────────────────────────────┐
│  This Week vs Last Week                     │
│  ─────────────────────────────────────────  │
│                                             │
│  Tasks Completed    18   →   23  (+28%)  ▲  │
│  Completion Rate    65%  →   72%  (+7%)  ▲  │
│  Overdue Tasks      5    →   3   (-40%)  ✓  │
│  Work-Life Balance  70/30 → 62/38        ✓  │
│                                             │
│  ┌──────────────────────────┐               │
│  │   This Week    Last Week │               │
│  │      ████         ███    │               │
│  │      ████         ███    │               │
│  │      ████         ███    │               │
│  │      ████                │               │
│  │      ████                │               │
│  └──────────────────────────┘               │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 9. Gamification & Motivation

### 9.1 Design Philosophy

**Principles** (inspired by research on Todoist Karma and healthy gamification):

1. **Intrinsic over Extrinsic**: Points should reinforce natural satisfaction, not replace it
2. **Progress over Competition**: Focus on personal growth, not leaderboards
3. **Celebrate Consistency**: Streaks and habits matter more than volume
4. **Avoid Punishment**: Don't penalize for rest days or changing priorities
5. **Optional Participation**: Users can hide gamification elements

### 9.2 Productivity Score System

```swift
struct ProductivityScore {
    let daily: Int      // 0-100
    let weekly: Int     // 0-100
    let streak: Int     // Days
    let level: Level

    enum Level: Int, CaseIterable {
        case beginner = 1      // 0-99 lifetime points
        case achiever = 2      // 100-499
        case organizer = 3     // 500-999
        case master = 4        // 1000-2499
        case expert = 5        // 2500-4999
        case grandmaster = 6   // 5000+

        var title: String {
            switch self {
            case .beginner: return "Beginner"
            case .achiever: return "Achiever"
            case .organizer: return "Organizer"
            case .master: return "Master"
            case .expert: return "Expert"
            case .grandmaster: return "Grandmaster"
            }
        }
    }
}
```

**Scoring Rules**:
- Complete task: +5 points
- Complete high-priority task: +10 points
- Complete before due date: +3 bonus
- Maintain streak day: +2 points
- Complete all daily tasks: +15 bonus
- Accurate time estimate (within 20%): +2 points

**Note**: Points are earned, never deducted. Missing a day simply doesn't add points.

### 9.3 Streaks Design

```
┌─────────────────────────────────────────────┐
│  🔥 Current Streak: 12 Days                 │
│  ─────────────────────────────────────────  │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  M   T   W   T   F   S   S         │    │
│  │  ●   ●   ●   ●   ●   ●   ○         │    │
│  │                          today      │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  Longest streak: 23 days                    │
│  Total productive days: 156                 │
│                                             │
│  Streak Protection: 1 remaining             │
│  (Freeze one day without breaking streak)   │
│                                             │
└─────────────────────────────────────────────┘
```

**Streak Rules**:
- Must complete at least 1 task to count as productive day
- Weekend days are optional (configurable)
- "Streak Protection" tokens: 1 per week, auto-used
- Streaks display prominently but tastefully

### 9.4 Achievements System

**Achievement Categories**:

| Category | Example Achievements |
|----------|---------------------|
| **Consistency** | 7-day streak, 30-day streak, 100-day streak |
| **Volume** | First task, 100 tasks, 1000 tasks completed |
| **Balance** | Week with all categories touched, Perfect WLB week |
| **Timing** | Early bird (before 7 AM), Night owl (after 9 PM) |
| **Estimation** | Perfect estimate (within 5%), Estimation master |
| **Projects** | First list, Project complete, Multi-project day |

**Achievement Card Design**:

```
┌─────────────────────────────────────────────┐
│  🏆 New Achievement Unlocked!               │
│  ─────────────────────────────────────────  │
│                                             │
│         ┌─────────────┐                     │
│         │    🔥       │                     │
│         │   30 Day    │                     │
│         │   Streak    │                     │
│         └─────────────┘                     │
│                                             │
│  "Consistency Champion"                     │
│  You've completed tasks for 30 days         │
│  straight! That's real dedication.          │
│                                             │
│  Earned: Feb 6, 2025                        │
│  Rarity: 12% of users                       │
│                                             │
│  [Share]              [View All Badges]     │
│                                             │
└─────────────────────────────────────────────┘
```

### 9.5 Personal Bests

```
┌─────────────────────────────────────────────┐
│  📊 Personal Records                        │
│  ─────────────────────────────────────────  │
│                                             │
│  Most Productive Day                        │
│  Jan 15, 2025 - 18 tasks completed          │
│                                             │
│  Longest Streak                             │
│  23 days (Dec 2024 - Jan 2025)              │
│                                             │
│  Best Week                                  │
│  Week of Jan 6, 2025 - 42 tasks, 89% rate   │
│                                             │
│  Best Category Performance                  │
│  Work: 95% completion (Week of Jan 20)      │
│                                             │
│  Perfect Balance Days                       │
│  3 days this month                          │
│                                             │
└─────────────────────────────────────────────┘
```

### 9.6 Privacy-Conscious Social Features

**Opt-In Only**:
- No automatic sharing
- No public leaderboards
- No social pressure mechanics

**If Implemented Later**:
- Share achievements to social media (user-initiated)
- Anonymous benchmark: "You're in the top 30% this week"
- Family/friend challenges (mutual opt-in)

---

## 10. Technical Implementation

### 10.1 Data Architecture

```swift
// Analytics Data Model Extensions
extension Task {
    // Already available fields for analytics:
    // - category: TaskCategory
    // - customCategoryID: UUID?
    // - listID: UUID?
    // - estimatedDuration: TimeInterval?
    // - accumulatedDuration: TimeInterval
    // - completedAt: Date?
    // - createdAt: Date
    // - updatedAt: Date
    // - priority: Priority
    // - isCompleted: Bool
}

// New Analytics Models
struct CategoryAnalytics: Codable {
    let category: TaskCategory
    let period: AnalyticsPeriod
    let tasksCreated: Int
    let tasksCompleted: Int
    let totalEstimatedMinutes: Int
    let totalActualMinutes: Int
    let completionRate: Double
    let averageCompletionTime: TimeInterval?
}

struct ListAnalytics: Codable {
    let listID: UUID
    let period: AnalyticsPeriod
    let tasksCreated: Int
    let tasksCompleted: Int
    let overdueCount: Int
    let velocity: Double // tasks per day
    let healthScore: Double
    let lastActivityDate: Date?
}

struct AnalyticsPeriod: Codable, Hashable {
    let start: Date
    let end: Date
    let type: PeriodType

    enum PeriodType: String, Codable {
        case day, week, month, quarter, year
    }
}
```

### 10.2 Efficient Query Strategies

**Challenge**: Analytics queries on potentially thousands of tasks

**Solution 1: Incremental Aggregation**

```swift
class AnalyticsAggregator {
    // Store pre-computed aggregates in Core Data
    @NSManaged var date: Date
    @NSManaged var category: Int16
    @NSManaged var listID: UUID?
    @NSManaged var completedCount: Int32
    @NSManaged var createdCount: Int32
    @NSManaged var totalMinutes: Int32

    // Update on task completion/creation
    static func recordCompletion(task: Task, context: NSManagedObjectContext) {
        // Find or create today's aggregate
        // Increment counts
        // O(1) write operation
    }

    // Query aggregates instead of raw tasks
    static func fetchWeeklyStats(for category: TaskCategory) -> [CategoryAnalytics] {
        // Fetch 7 aggregate records instead of N tasks
        // O(7) instead of O(N)
    }
}
```

**Solution 2: Materialized Views (Cached Computations)**

```swift
struct AnalyticsCache {
    static let shared = AnalyticsCache()

    private var categoryStatsCache: [AnalyticsPeriod: [CategoryAnalytics]] = [:]
    private var lastInvalidation: Date = .distantPast

    func getCategoryStats(for period: AnalyticsPeriod) async -> [CategoryAnalytics] {
        // Check cache validity
        if let cached = categoryStatsCache[period],
           lastInvalidation < period.start {
            return cached
        }

        // Compute and cache
        let stats = await computeCategoryStats(for: period)
        categoryStatsCache[period] = stats
        return stats
    }

    func invalidate() {
        lastInvalidation = Date()
    }
}
```

**Solution 3: Background Computation**

```swift
class AnalyticsBackgroundService {
    func scheduleNightlyComputation() {
        // Use BGProcessingTask for iOS background execution
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.lazyflow.analytics.compute",
            using: nil
        ) { task in
            self.computeAllAnalytics(task: task as! BGProcessingTask)
        }
    }

    private func computeAllAnalytics(task: BGProcessingTask) {
        // Compute weekly/monthly aggregates
        // Store in UserDefaults or Core Data
        // Takes 1-5 seconds typically
    }
}
```

### 10.3 Memory-Efficient Chart Data

```swift
// Instead of loading all tasks
// Load aggregated data points only
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let category: TaskCategory?
}

// Fetch last 30 days with 1 data point per day
// = 30 objects instead of potentially thousands of tasks
func fetchCompletionTrend(days: Int = 30) -> [ChartDataPoint] {
    // SQL: SELECT date, COUNT(*) FROM tasks WHERE completedAt >= ? GROUP BY date
}
```

### 10.4 Caching Strategy

| Data Type | Cache Duration | Invalidation Trigger |
|-----------|----------------|---------------------|
| Today's stats | 5 minutes | Task completion/creation |
| Weekly aggregates | 1 hour | Task completion/creation |
| Monthly trends | 6 hours | Nightly recompute |
| Historical data | 24 hours | Nightly recompute |
| Achievement progress | 15 minutes | Task completion |

```swift
class AnalyticsCacheManager {
    enum CacheKey: String {
        case todayStats
        case weeklyCategory
        case monthlyTrends
        case achievements
    }

    func get<T: Codable>(_ key: CacheKey) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key.rawValue),
              let cached = try? JSONDecoder().decode(CachedValue<T>.self, from: data),
              cached.expiresAt > Date() else {
            return nil
        }
        return cached.value
    }

    func set<T: Codable>(_ value: T, for key: CacheKey, duration: TimeInterval) {
        let cached = CachedValue(value: value, expiresAt: Date().addingTimeInterval(duration))
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: key.rawValue)
        }
    }
}
```

### 10.5 Core Data Fetch Request Optimization

```swift
extension TaskService {
    /// Optimized fetch for analytics - only loads required fields
    func fetchAnalyticsData(
        from startDate: Date,
        to endDate: Date,
        properties: [String] = ["id", "category", "completedAt", "estimatedDuration", "listID"]
    ) -> [NSDictionary] {
        let request = NSFetchRequest<NSDictionary>(entityName: "TaskEntity")
        request.predicate = NSPredicate(
            format: "completedAt >= %@ AND completedAt <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        request.propertiesToFetch = properties
        request.resultType = .dictionaryResultType

        // Returns lightweight dictionaries instead of full managed objects
        return (try? context.fetch(request)) ?? []
    }
}
```

---

## 11. Industry Analysis

### 11.1 Apple Screen Time

**What Works**:
- Weekly reports with clear week-over-week comparisons
- App category groupings (Social, Productivity, Entertainment)
- Daily vs weekly toggle
- Time-based heat maps
- Downtime scheduling integration
- Widget for quick glance

**What to Adopt**:
- Simple category groupings with drill-down
- Week-over-week comparison prominently displayed
- Clean, minimal chart design
- Widget integration for key metric

**What to Improve On**:
- Screen Time is observation-only; we add actionable recommendations
- Screen Time doesn't have goals; we enable custom targets
- No positive reinforcement; we celebrate achievements

### 11.2 Todoist Karma

**What Works**:
- Points system creates engagement
- Levels provide progression milestones
- Streak tracking encourages consistency
- Weekly goals with visual progress
- Colored productivity graphs

**What to Adopt**:
- Streak system with visual representation
- Level progression tied to lifetime productivity
- Daily/weekly goal tracking

**What to Avoid**:
- Point deduction for overdue tasks (creates anxiety)
- Public leaderboards (creates unhealthy competition)
- Gamification that feels mandatory

**Lazyflow Differentiation**:
- Focus on balance, not just volume
- Category insights Todoist lacks
- Calendar integration for time context

### 11.3 Strava/Garmin Analytics

**What Works**:
- Personal records prominently displayed
- Training load and recovery metrics
- Social kudos (optional, positive-only)
- Segment comparison (self-improvement focus)
- Beautiful data visualization
- Detailed activity breakdowns

**What to Adopt**:
- Personal bests as motivators
- Activity-type breakdowns (like our categories)
- Visual progress over time
- Comparison to personal history, not others

**What to Learn**:
- Fitness apps successfully balance data depth with usability
- Users engage more with progress visualization than raw numbers

### 11.4 RescueTime

**What Works**:
- Automatic time tracking (we don't have this, but duration tracking is similar)
- Productivity Pulse score (0-100)
- Category-based time analysis
- Focus time detection
- Daily/weekly email reports

**What to Adopt**:
- Productivity score concept (adapted for task completion)
- Category-based insights
- Email/notification summary option
- Focus time analysis (via calendar integration)

**What to Improve On**:
- RescueTime is passive observation; we're active task management
- We have explicit user intent (task categories) vs inferred from app usage

### 11.5 Competitive Feature Matrix

| Feature | Lazyflow | Todoist | Things | RescueTime |
|---------|----------|---------|--------|------------|
| Task completion analytics | ✓ | ✓ | ✗ | ✗ |
| Category insights | ✓ | ✗ | ✗ | ✓ |
| Time estimation tracking | ✓ | ✓ | ✗ | ✗ |
| Calendar integration | ✓ | ✗ | ✗ | ✗ |
| Work-life balance | ✓ | ✗ | ✗ | ✓ |
| Streaks | ✓ | ✓ | ✗ | ✗ |
| Achievements | ✓ | ✓ | ✗ | ✗ |
| AI insights | ✓ | ✗ | ✗ | ✗ |
| List/project analytics | ✓ | ✓ | ✓ | ✗ |
| Native iOS design | ✓ | ✗ | ✓ | ✗ |

---

## 12. Data Model Extensions

### 12.1 New Core Data Entities

```swift
// AnalyticsAggregate - Daily pre-computed stats
entity AnalyticsAggregate {
    attribute id: UUID
    attribute date: Date
    attribute categoryRaw: Int16
    attribute listID: UUID?
    attribute tasksCreated: Int32
    attribute tasksCompleted: Int32
    attribute totalEstimatedMinutes: Int32
    attribute totalActualMinutes: Int32
    attribute highPriorityCompleted: Int32
    attribute overdueCompleted: Int32
}

// Achievement - Unlocked badges
entity Achievement {
    attribute id: String // e.g., "streak_30"
    attribute unlockedAt: Date
    attribute category: String // "consistency", "volume", etc.
    attribute metadata: Data? // JSON for additional info
}

// ProductivityGoal - User-defined targets
entity ProductivityGoal {
    attribute id: UUID
    attribute type: String // "daily_tasks", "weekly_category", "monthly_balance"
    attribute targetValue: Double
    attribute categoryRaw: Int16?
    attribute listID: UUID?
    attribute startDate: Date
    attribute endDate: Date?
    attribute isActive: Bool
}
```

### 12.2 UserDefaults Keys

```swift
enum AnalyticsUserDefaults {
    static let currentStreak = "analytics_current_streak"
    static let longestStreak = "analytics_longest_streak"
    static let lastProductiveDate = "analytics_last_productive_date"
    static let lifetimePoints = "analytics_lifetime_points"
    static let currentLevel = "analytics_current_level"
    static let unlockedAchievements = "analytics_unlocked_achievements"
    static let weeklyGoal = "analytics_weekly_goal"
    static let workLifeTarget = "analytics_work_life_target"
    static let gamificationEnabled = "analytics_gamification_enabled"
    static let lastAnalyticsCompute = "analytics_last_compute"
}
```

### 12.3 Analytics Service Interface

```swift
protocol AnalyticsServiceProtocol {
    // Category Analytics
    func getCategoryStats(for period: AnalyticsPeriod) async -> [CategoryAnalytics]
    func getCategoryTrend(category: TaskCategory, periods: Int) async -> [TrendDataPoint]
    func getWorkLifeBalance(for period: AnalyticsPeriod) async -> WorkLifeBalance

    // List Analytics
    func getListStats(for period: AnalyticsPeriod) async -> [ListAnalytics]
    func getListHealth(listID: UUID) async -> ListHealthScore
    func getStaleLists() async -> [TaskList]

    // Combined Insights
    func getCategoryByListMatrix(for period: AnalyticsPeriod) async -> CategoryListMatrix
    func detectPatterns() async -> [InsightPattern]

    // Recommendations
    func generateInsights() async -> [Insight]
    func getActionableRecommendations() async -> [Recommendation]

    // Gamification
    func getCurrentStreak() -> StreakData
    func getProductivityScore(for period: AnalyticsPeriod) -> ProductivityScore
    func checkAchievements() async -> [Achievement]
    func getLevel() -> ProductivityScore.Level

    // Goals
    func setGoal(_ goal: ProductivityGoal) async
    func getGoalProgress(goalID: UUID) async -> GoalProgress
}
```

---

## 13. UI/UX Specifications

### 13.1 Insights Tab Structure

```
┌─────────────────────────────────────────────┐
│  Insights                              ⚙️    │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ 🔥 12 Day Streak        Level: Master│   │
│  │ ████████████████░░░░ 2,450 pts      │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  [Day] [Week ✓] [Month] [Quarter]           │
│  ◄  Feb 3 - 9, 2025  ►                      │
│                                             │
│  ─── Overview ───                           │
│  ┌─────────────────────────────────────┐    │
│  │ Tasks      Completion    Balance    │    │
│  │   23          72%        62/38      │    │
│  │   ▲15%        ▲8%         ✓         │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ─── Insights ───                           │
│  ┌─────────────────────────────────────┐    │
│  │ ⚠️ Health tasks need attention       │    │
│  │ Only 35% completion this week       │    │
│  │ [Schedule Health Time]              │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ─── Categories ───                         │
│  [View Category Distribution Chart]         │
│  [View Completion Rates]                    │
│  [View Best Times]                          │
│                                             │
│  ─── Projects ───                           │
│  [View Project Velocity]                    │
│  [View List Health]                         │
│  [View Overdue Analysis]                    │
│                                             │
│  ─── Achievements ───                       │
│  [View All Badges] (3 new)                  │
│                                             │
└─────────────────────────────────────────────┘
```

### 13.2 Navigation Flow

```
Insights Tab
├── Overview Dashboard (default)
│   ├── Streak & Level Badge
│   ├── Period Selector
│   ├── Quick Stats Cards
│   └── Active Insights
│
├── Category Analytics
│   ├── Distribution Chart
│   ├── Completion Rates
│   ├── Trends Over Time
│   ├── Best Times Heatmap
│   └── Work-Life Balance
│
├── Project Analytics
│   ├── Velocity Dashboard
│   ├── Health Matrix
│   ├── Stale Projects
│   └── Overdue Analysis
│
├── Patterns & Insights
│   ├── Detected Patterns
│   ├── Recommendations
│   └── Category-List Matrix
│
├── Achievements
│   ├── Unlocked Badges
│   ├── Progress to Next
│   └── Personal Records
│
└── Settings
    ├── Work-Life Categories
    ├── Goals
    ├── Gamification Toggle
    └── Notification Preferences
```

### 13.3 Component Design Tokens

```swift
extension DesignSystem {
    enum Analytics {
        // Chart colors (colorblind-safe palette)
        static let chartColors: [Color] = [
            Color(hex: "#0077BB"),  // Blue - Work
            Color(hex: "#882255"),  // Purple - Personal
            Color(hex: "#009988"),  // Teal - Health
            Color(hex: "#33BBEE"),  // Cyan - Finance
            Color(hex: "#EE7733"),  // Orange - Shopping
            Color(hex: "#CCBB44"),  // Yellow - Errands
            Color(hex: "#0099CC"),  // Light Blue - Learning
            Color(hex: "#AA4499"),  // Magenta - Home
        ]

        // Trend indicators
        static let positiveColor = Color.green
        static let negativeColor = Color.red
        static let neutralColor = Color.secondary

        // Achievement colors
        static let goldBadge = Color(hex: "#FFD700")
        static let silverBadge = Color(hex: "#C0C0C0")
        static let bronzeBadge = Color(hex: "#CD7F32")

        // Chart dimensions
        static let chartHeight: CGFloat = 240
        static let sparklineHeight: CGFloat = 32
        static let progressRingSize: CGFloat = 120

        // Spacing
        static let cardSpacing: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
    }
}
```

### 13.4 Empty States

```
┌─────────────────────────────────────────────┐
│                                             │
│              📊                             │
│                                             │
│        Not Enough Data Yet                  │
│                                             │
│   Complete a few more tasks to see your     │
│   productivity insights and patterns.       │
│                                             │
│   Analytics unlock after:                   │
│   • 7 days of activity                      │
│   • 10+ completed tasks                     │
│                                             │
│   [View Today's Tasks]                      │
│                                             │
└─────────────────────────────────────────────┘
```

### 13.5 Loading States

```swift
// Skeleton loading for charts
struct ChartSkeletonView: View {
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 240)
                .shimmer() // Custom shimmer animation
        }
    }
}

// Progressive loading
struct InsightsView: View {
    @State private var loadingPhase: LoadingPhase = .overview

    enum LoadingPhase {
        case overview   // Load first (< 100ms)
        case charts     // Load second (< 500ms)
        case insights   // Load third (< 1s)
    }
}
```

---

## 14. Accessibility Requirements

### 14.1 VoiceOver Support

```swift
// Chart accessibility
Chart(data) { item in
    BarMark(...)
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Category completion rates chart")
.accessibilityValue(generateChartSummary(data))
// "Work 82%, Personal 71%, Health 35%. Health is below target."

// Individual data points
BarMark(...)
    .accessibilityLabel("\(item.category.displayName)")
    .accessibilityValue("\(item.rate, format: .percent) completion rate")
    .accessibilityHint("Double tap to view details")
```

### 14.2 Dynamic Type Support

All text must scale with Dynamic Type:
- Stat values: `.title` or `.title2`
- Labels: `.body` or `.callout`
- Captions: `.caption` or `.footnote`

Charts must remain readable at larger text sizes:
- Increase chart height proportionally
- Use scrollable legends when space constrained
- Provide text-only alternative view

### 14.3 Reduce Motion

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Disable chart animations when reduce motion enabled
.chartAnimation(reduceMotion ? nil : .easeInOut)

// Skip celebration animations
if !reduceMotion {
    showConfettiAnimation()
}
```

### 14.4 Color Alternatives

All color-coded information must have non-color alternative:
- Pattern fills for chart segments
- Text labels alongside colored indicators
- Icons paired with colors

### 14.5 Minimum Touch Targets

All interactive elements: minimum 44x44pt
- Chart segment tap targets expanded via `.contentShape()`
- Legend items spaced appropriately
- Period selector buttons sized correctly

---

## 15. Testing Strategy

### 15.1 Unit Tests

```swift
class AnalyticsServiceTests: XCTestCase {

    // Metric calculations
    func testCompletionRateCalculation() {
        let service = AnalyticsService(taskService: mockTaskService)

        // Given 10 completed, 15 total
        mockTaskService.stubbedCompletedCount = 10
        mockTaskService.stubbedTotalCount = 15

        // When
        let rate = service.calculateCompletionRate(for: .work)

        // Then
        XCTAssertEqual(rate, 0.667, accuracy: 0.01)
    }

    func testWorkLifeBalanceScore() {
        // Test perfect balance
        let perfectScore = service.calculateWLBScore(workRatio: 0.6, target: 0.6)
        XCTAssertEqual(perfectScore, 100)

        // Test 10% deviation
        let goodScore = service.calculateWLBScore(workRatio: 0.7, target: 0.6)
        XCTAssertEqual(goodScore, 90)
    }

    func testStaleListDetection() {
        let stale = service.detectStaleLists()
        XCTAssertTrue(stale.contains(where: { $0.id == inactiveListID }))
    }

    // Streak logic
    func testStreakContinuation() {
        streakData.recordDay(date: yesterday, wasProductive: true)
        streakData.recordDay(date: today, wasProductive: true)
        XCTAssertEqual(streakData.currentStreak, 2)
    }

    func testStreakBreak() {
        streakData.recordDay(date: threeDaysAgo, wasProductive: true)
        streakData.recordDay(date: today, wasProductive: true)
        XCTAssertEqual(streakData.currentStreak, 1) // Broken by gap
    }
}
```

### 15.2 Performance Tests

```swift
class AnalyticsPerformanceTests: XCTestCase {

    func testLargeDatasetQuery() {
        // Given 10,000 tasks over 1 year
        setupLargeDataset(taskCount: 10000)

        measure {
            // When querying monthly stats
            let stats = analyticsService.getCategoryStats(for: .month(Date()))

            // Then should complete in < 500ms
            XCTAssertNotNil(stats)
        }
    }

    func testChartDataMemoryUsage() {
        // Verify chart data doesn't load full task objects
        let dataPoints = analyticsService.fetchCompletionTrend(days: 365)

        // Should be 365 lightweight objects, not 10,000+ tasks
        XCTAssertLessThanOrEqual(dataPoints.count, 365)
    }
}
```

### 15.3 UI Tests

```swift
class InsightsUITests: XCTestCase {

    func testPeriodSwitching() {
        app.buttons["Week"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "periodLabel").firstMatch.label.contains("Week"))

        app.buttons["Month"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "periodLabel").firstMatch.label.contains("Month"))
    }

    func testChartInteraction() {
        // Tap chart segment
        app.otherElements["categoryChart"].tap()

        // Verify detail popup appears
        XCTAssertTrue(app.staticTexts["Work"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '%'")).firstMatch.exists)
    }

    func testAccessibilityLabels() {
        // Verify VoiceOver labels present
        let chart = app.otherElements["categoryChart"]
        XCTAssertNotNil(chart.value)
        XCTAssertTrue(chart.isAccessibilityElement)
    }
}
```

### 15.4 Snapshot Tests

Capture visual snapshots for:
- Empty state
- Loading state
- Full data state (light mode)
- Full data state (dark mode)
- Large Dynamic Type
- Colorblind simulation

### 15.5 Data Validation Tests

```swift
func testNoNegativeMetrics() {
    let stats = analyticsService.getAllCategoryStats()

    for stat in stats {
        XCTAssertGreaterThanOrEqual(stat.completionRate, 0)
        XCTAssertLessThanOrEqual(stat.completionRate, 1)
        XCTAssertGreaterThanOrEqual(stat.tasksCompleted, 0)
    }
}

func testDateRangeConsistency() {
    let weekStats = analyticsService.getCategoryStats(for: .thisWeek)
    let totalFromDays = (0..<7).map {
        analyticsService.getCategoryStats(for: .day(Date().addingTimeInterval(-Double($0) * 86400)))
    }.flatMap { $0 }.reduce(0) { $0 + $1.tasksCompleted }

    let weekTotal = weekStats.reduce(0) { $0 + $1.tasksCompleted }
    XCTAssertEqual(weekTotal, totalFromDays)
}
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Data model extensions (AnalyticsAggregate entity)
- [ ] AnalyticsService basic implementation
- [ ] Category completion rate calculation
- [ ] Basic Insights tab UI skeleton

### Phase 2: Category Insights (Week 3-4)
- [ ] Category distribution donut chart
- [ ] Completion rate bar chart
- [ ] Work-life balance gauge
- [ ] Category trends line chart

### Phase 3: List Insights (Week 5-6)
- [ ] Project velocity calculations
- [ ] List health score implementation
- [ ] Stale list detection
- [ ] Overdue analysis by list

### Phase 4: Recommendations (Week 7-8)
- [ ] Insight generation engine
- [ ] Pattern detection algorithms
- [ ] Recommendation action handlers
- [ ] Nudge notification system

### Phase 5: Gamification (Week 9-10)
- [ ] Streak tracking enhancement
- [ ] Achievement system
- [ ] Level progression
- [ ] Personal bests tracking

### Phase 6: Polish (Week 11-12)
- [ ] Performance optimization
- [ ] Caching implementation
- [ ] Accessibility audit
- [ ] UI refinement and animations

---

## Dependencies

- Issue #110 - Navigation restructure with Insights tab (required, v1.8)
- Issue #66 - Custom categories (required, v1.6)
- Existing: DailySummaryService (extend for analytics)
- Existing: TaskService (add analytics queries)
- Existing: Swift Charts (iOS 16+)

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Insights tab engagement | > 50% weekly active users view | Analytics tracking |
| Actionable insight tap rate | > 30% of displayed insights | Analytics tracking |
| Task completion rate increase | +10% after 30 days of analytics use | A/B test |
| User satisfaction | > 4.0/5 for analytics features | In-app survey |
| Performance | All charts render < 500ms | Performance monitoring |

---

## References

1. [Modern Productivity Metrics That Actually Matter in 2025](https://www.edstellar.com/blog/team-productivity-metrics)
2. [Productivity Research Studies from 2025](https://desktime.com/blog/productivity-research-studies-2025)
3. [Work-Life Balance Measurement Research](https://pmc.ncbi.nlm.nih.gov/articles/PMC11919065/)
4. [Accessibility-First Chart Design](https://www.smashingmagazine.com/2022/07/accessibility-first-approach-chart-visual-design/)
5. [Todoist Karma Gamification Case Study](https://trophy.so/blog/todoist-gamification-case-study)
6. [Apple Screen Time Design](https://support.apple.com/guide/iphone/get-started-with-screen-time-iphbfa595995/ios)
7. [Swift Charts Documentation](https://developer.apple.com/documentation/Charts)
8. [Colorblind-Safe Palettes for Data Visualization](https://medium.com/galaxy-ux-studio/design-guidelines-for-color-blind-users-fac6b686c4df)
9. [RescueTime Productivity Reports](https://help.rescuetime.com/article/61-the-productivity-report)
10. [iOS Accessibility Best Practices](https://afixt.com/mobile-app-accessibility-best-practices-for-inclusive-design/)
