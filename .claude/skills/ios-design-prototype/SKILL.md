---
disable-model-invocation: true
argument-hint: "[component-name]"
description: "Create interactive iOS design prototypes as HTML files with iPhone frames, Lazyflow design tokens, and Codex review"
---

# iOS Design Prototype

Create interactive HTML prototypes that mirror the Lazyflow iOS app's design system. Output files go to `docs/design/`. Use the `frontend-design` skill for visual quality and Codex MCP for design review.

## Phase 1: Research

1. Read the argument to understand what component/screen to prototype
2. Spin up parallel Task agents to gather context:
   - **Agent 1 (Explore):** Find existing SwiftUI views related to the component — read layout, state, actions
   - **Agent 2 (Explore):** Read `DesignSystem.swift` and `Color+Extensions.swift` for current tokens
   - **Agent 3 (Explore):** Find any existing prototypes in `docs/design/` for patterns to follow
3. If the component exists in the app, extract: layout hierarchy, actions/gestures, states (empty, loading, error, populated), animations

**Exit criteria:** You can describe the component's layout, states, and interactions.

## Phase 2: Design Direction

1. Consult Codex for design direction:
   ```
   mcp__codex__codex prompt: "I'm designing [component] for an iOS todo app (Lazyflow).
   Context: [what you learned in Phase 1]. Recommend: layout approach, interaction
   patterns, animation strategy, and any iOS HIG considerations. Keep it concise —
   3-5 bullet points per category."
   ```
2. Synthesize Codex feedback with existing app patterns
3. Decide on: layout structure, interaction model, animation budget, states to show

**Exit criteria:** Clear design direction with Codex input.

## Phase 3: Build Prototype

Invoke the `frontend-design` skill mindset for visual quality, but constrain to Lazyflow's design system (not generic web aesthetics).

### Template Structure

Generate a single HTML file with this structure:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Lazyflow — {Component Name}</title>
  <style>
    /* 1. Design System Tokens (CSS variables) */
    /* 2. iPhone Frame */
    /* 3. Component Styles */
    /* 4. Animations */
    /* 5. Theme Toggle */
  </style>
</head>
<body>
  <!-- Phone frames with interactive demos -->
  <!-- Theme toggle -->
  <script>
    /* Interactive behavior */
  </script>
</body>
</html>
```

### Design System Tokens (always include)

```css
:root {
  /* Spacing — maps to DesignSystem.Spacing */
  --space-xxs: 2px; --space-xs: 4px; --space-sm: 8px;
  --space-md: 12px; --space-lg: 16px; --space-xl: 20px;
  --space-xxl: 24px; --space-xxxl: 32px;

  /* Corner Radius — maps to DesignSystem.CornerRadius */
  --radius-sm: 4px; --radius-md: 8px; --radius-lg: 12px; --radius-xl: 16px;

  /* Typography — maps to DesignSystem.Typography (SF Pro system font) */
  --font: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', system-ui, sans-serif;
  --text-large-title: 700 34px/1.2 var(--font);
  --text-title1: 700 28px/1.2 var(--font);
  --text-title2: 700 22px/1.25 var(--font);
  --text-title3: 600 20px/1.25 var(--font);
  --text-headline: 600 17px/1.3 var(--font);
  --text-body: 400 17px/1.3 var(--font);
  --text-callout: 400 16px/1.3 var(--font);
  --text-subheadline: 400 15px/1.35 var(--font);
  --text-footnote: 400 13px/1.35 var(--font);
  --text-caption1: 400 12px/1.3 var(--font);
  --text-caption2: 400 11px/1.3 var(--font);

  /* Touch Targets */
  --touch-min: 44px; --touch-comfortable: 48px; --touch-large: 56px;

  /* Animation — maps to DesignSystem.Animation */
  --anim-quick: 0.15s ease-in-out;
  --anim-standard: 0.25s ease-in-out;
  --anim-slow: 0.4s ease-in-out;
  --anim-spring: 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
}

/* Light theme (default) */
[data-theme="light"] {
  --accent: #218A8D; --accent-light: #2BA5A8; --accent-dark: #1A6F71;
  --bg: #F5F5F5; --surface: #FFFFFF;
  --text-primary: #1C1C1E; --text-secondary: #6B7280; --text-tertiary: #5A6C71;
  --success: #22C876; --error: #FF5459; --warning: #E68157; --info: #5A6C71;
  --shadow-sm: 0 2px 4px rgba(0,0,0,0.08);
  --shadow-md: 0 4px 8px rgba(0,0,0,0.12);
}

/* Dark theme */
[data-theme="dark"] {
  --accent: #218A8D; --accent-light: #2BA5A8; --accent-dark: #1A6F71;
  --bg: #1F2121; --surface: #272A2A;
  --text-primary: #F5F5F5; --text-secondary: #9CA3AF; --text-tertiary: #5A6C71;
  --success: #22C876; --error: #FF5459; --warning: #E68157; --info: #5A6C71;
  --shadow-sm: 0 2px 4px rgba(0,0,0,0.3);
  --shadow-md: 0 4px 8px rgba(0,0,0,0.4);
}
```

### iPhone Frame (always include)

```css
.phone-wrapper {
  transform: scale(0.78); transform-origin: top center; margin-bottom: -150px;
}
.phone-frame {
  width: 402px; height: 874px; /* iPhone 17 Pro logical points */
  border-radius: 55px; overflow: hidden; position: relative;
  border: 8px solid #1a1a1a; background: var(--bg);
  box-shadow: 0 20px 60px rgba(0,0,0,0.3), inset 0 0 2px rgba(255,255,255,0.1);
}
.phone-notch {
  position: absolute; top: 0; left: 50%; transform: translateX(-50%);
  width: 126px; height: 35px; background: #1a1a1a;
  border-radius: 0 0 20px 20px; z-index: 100;
}
.phone-screen { padding: 60px 20px 40px; height: 100%; overflow-y: auto; }
```

### Requirements

- **All buttons/interactions must work** — checkbox completion, toggles, menus, navigation
- **Both light and dark themes** — toggle button outside phone frames
- **Show multiple states** when useful — use separate phone frames side-by-side (e.g., populated + empty state)
- **Animations must match iOS feel** — spring curves, not linear; respect motion budget (max 3 simultaneous animations)
- **Use SF Symbols names in comments** — even though HTML uses text/SVG, note the SF Symbol name for implementation reference
- **Scale phone to fit screen** — use `transform: scale(0.78)` on wrapper so phones are visible without scrolling
- **Match real app patterns** — strikethrough on completion, badge styles, card shadows, etc.

## Phase 4: Codex Design Review

Send the prototype to Codex for review:

```
mcp__codex__codex prompt: "Review this iOS design prototype for [component].
Design system: Lazyflow (teal accent #218A8D, SF Pro, iOS HIG).
Evaluate: visual hierarchy, interaction patterns, animation appropriateness,
iOS platform conventions, accessibility. Rate each 1-5 and suggest improvements.
Focus on what would make this feel native and polished on iOS."
```

Apply feedback. If changes are significant, re-review (max 2 review rounds).

## Phase 5: Finalize

1. Save to `docs/design/{component-name}.html`
2. Verify the file opens correctly in a browser
3. Summarize: what was built, key design decisions, Codex feedback applied, and notes for SwiftUI implementation

## Output

Single interactive HTML file at `docs/design/{component-name}.html` with:
- Lazyflow design tokens as CSS variables
- iPhone 17 Pro frame(s) at 402x874
- All interactions functional
- Light/dark theme toggle
- Implementation notes as HTML comments where SwiftUI mapping isn't obvious
