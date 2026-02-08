---
user-invocable: false
description: "Design system knowledge for SwiftUI view development"
---

# SwiftUI Component Patterns

Auto-loaded when creating or modifying SwiftUI views. Reference `docs/project/design-system.md` for the full specification.

## Design Tokens

**Spacing:** `DesignSystem.Spacing.{xxs(2), xs(4), sm(8), md(12), lg(16), xl(20), xxl(24), xxxl(32)}`
**Typography:** `DesignSystem.Typography.{largeTitle, title1, title2, title3, headline, body, callout, subheadline, footnote, caption1, caption2}`
**Corner Radius:** `DesignSystem.CornerRadius.{small(8), medium(12), large(16), extraLarge(24)}`
**Colors:**
- Brand: `Color.Lazyflow.{accent, textPrimary, textSecondary, textTertiary}`
- Semantic: `Color.Lazyflow.{success, error, warning}`
- Adaptive: `Color.adaptiveBackground`, `Color.adaptiveSurface`
**Buttons:** `PrimaryButtonStyle()`, `SecondaryButtonStyle()`

## ViewModel Pattern

```swift
@MainActor final class FooViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false

    private let service: FooServiceProtocol

    init(service: FooServiceProtocol = FooService.shared) {
        self.service = service
    }
}
```

## Sheet Flow Pattern

```swift
.sheet(isPresented: $showSheet) {
    NavigationStack {
        SheetContentView()
            .navigationTitle("Title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSheet = false }
                }
            }
    }
}
```

Load data with `.task { await viewModel.loadData() }`

## Prompt Card Pattern (TodayView)

```swift
Button { /* action */ } label: {
    HStack(spacing: DesignSystem.Spacing.md) {
        Circle().fill(Color.Lazyflow.accent).frame(width: 36, height: 36)
            .overlay(Image(systemName: "icon").foregroundColor(.white))
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Text("Title").font(DesignSystem.Typography.headline)
            Text("Subtitle").font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textSecondary)
        }
        Spacer()
        Image(systemName: "chevron.right").foregroundColor(Color.Lazyflow.textTertiary)
    }
}
.buttonStyle(.plain)
```

## Checklist

- [ ] Uses DesignSystem tokens (not hardcoded values)
- [ ] Touch targets >= 44pt
- [ ] VoiceOver labels on interactive elements
- [ ] Supports both light and dark mode
- [ ] TodayView List sections always present (even when empty) to prevent crashes
