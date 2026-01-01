import WidgetKit
import SwiftUI

// MARK: - Complication Entry

struct TaskComplicationEntry: TimelineEntry {
    let date: Date
    let completedCount: Int
    let totalCount: Int
    let currentTaskTitle: String?

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var remainingCount: Int {
        totalCount - completedCount
    }

    static var placeholder: TaskComplicationEntry {
        TaskComplicationEntry(
            date: Date(),
            completedCount: 2,
            totalCount: 5,
            currentTaskTitle: "Review pull request"
        )
    }
}

// MARK: - Timeline Provider

struct TaskComplicationProvider: TimelineProvider {
    private let dataStore = WatchDataStore.shared

    func placeholder(in context: Context) -> TaskComplicationEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskComplicationEntry) -> Void) {
        let entry = createEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskComplicationEntry>) -> Void) {
        let entry = createEntry()

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }

    private func createEntry() -> TaskComplicationEntry {
        let tasks = dataStore.todayTasks
        let completedCount = tasks.filter { $0.isCompleted }.count
        let totalCount = tasks.count
        let currentTask = tasks.first { !$0.isCompleted }?.title

        return TaskComplicationEntry(
            date: Date(),
            completedCount: completedCount,
            totalCount: totalCount,
            currentTaskTitle: currentTask
        )
    }
}

// MARK: - Complication Widget

struct TaskweaveComplication: Widget {
    let kind: String = "TaskweaveComplication"

    private let accentColor = Color(red: 33/255, green: 138/255, blue: 141/255)

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskComplicationProvider()) { entry in
            ComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Taskweave")
        .description("Track your daily task progress")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}

// MARK: - Complication Views

struct ComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TaskComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        default:
            CircularComplicationView(entry: entry)
        }
    }
}

// MARK: - Circular (Progress Ring)

struct CircularComplicationView: View {
    let entry: TaskComplicationEntry

    private let accentColor = Color(red: 33/255, green: 138/255, blue: 141/255)

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 4)

            // Progress
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Count or checkmark
            if entry.progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accentColor)
            } else {
                Text("\(entry.remainingCount)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
        }
        .widgetAccentable()
    }
}

// MARK: - Corner

struct CornerComplicationView: View {
    let entry: TaskComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Text("\(entry.remainingCount)")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
        }
        .widgetLabel {
            Text("tasks")
        }
    }
}

// MARK: - Inline

struct InlineComplicationView: View {
    let entry: TaskComplicationEntry

    var body: some View {
        if entry.totalCount == 0 {
            Text("No tasks today")
        } else if entry.remainingCount == 0 {
            Text("All done!")
        } else {
            Text("\(entry.remainingCount) task\(entry.remainingCount == 1 ? "" : "s") left")
        }
    }
}

// MARK: - Rectangular

struct RectangularComplicationView: View {
    let entry: TaskComplicationEntry

    private let accentColor = Color(red: 33/255, green: 138/255, blue: 141/255)

    var body: some View {
        HStack(spacing: 8) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(
                        accentColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                if let currentTask = entry.currentTaskTitle {
                    Text(currentTask)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }

                Text("\(entry.completedCount)/\(entry.totalCount) done")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .widgetAccentable()
    }
}

#Preview(as: .accessoryCircular) {
    TaskweaveComplication()
} timeline: {
    TaskComplicationEntry.placeholder
}
