import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity widget configuration for task tracking
struct TaskweaveLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaskActivityAttributes.self) { context in
            // Lock Screen / Banner presentation
            LockScreenLiveActivityView(context: context)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions (shown on long press)
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandExpandedLeading(state: context.state)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    DynamicIslandExpandedTrailing(state: context.state)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    DynamicIslandExpandedView(state: context.state)
                }

            } compactLeading: {
                // Compact left side (always visible)
                DynamicIslandCompactLeading(state: context.state)

            } compactTrailing: {
                // Compact right side (always visible)
                DynamicIslandCompactTrailing(state: context.state)

            } minimal: {
                // Minimal view (when multiple activities are active)
                DynamicIslandMinimal(state: context.state)
            }
        }
    }
}
