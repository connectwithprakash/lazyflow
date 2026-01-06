import WidgetKit
import SwiftUI

/// Main Lazyflow widget providing task overview
struct LazyflowWidget: Widget {
    let kind: String = "LazyflowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskTimelineProvider()) { entry in
            LazyflowWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Lazyflow")
        .description("View your tasks at a glance")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Entry view that selects appropriate widget size
struct LazyflowWidgetEntryView: View {
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
    LazyflowWidget()
} timeline: {
    TaskEntry.placeholder
}

#Preview(as: .systemMedium) {
    LazyflowWidget()
} timeline: {
    TaskEntry.placeholder
}

#Preview(as: .systemLarge) {
    LazyflowWidget()
} timeline: {
    TaskEntry.placeholder
}
