import WidgetKit
import SwiftUI

/// Main Taskweave widget providing task overview
struct TaskweaveWidget: Widget {
    let kind: String = "TaskweaveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskTimelineProvider()) { entry in
            TaskweaveWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Taskweave")
        .description("View your tasks at a glance")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Entry view that selects appropriate widget size
struct TaskweaveWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: TaskEntry

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

#Preview(as: .systemSmall) {
    TaskweaveWidget()
} timeline: {
    TaskEntry.placeholder
}

#Preview(as: .systemMedium) {
    TaskweaveWidget()
} timeline: {
    TaskEntry.placeholder
}

#Preview(as: .systemLarge) {
    TaskweaveWidget()
} timeline: {
    TaskEntry.placeholder
}
