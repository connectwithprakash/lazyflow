import SwiftUI
import WidgetKit

/// Small widget (2x2) showing task count and circular completion progress
struct SmallWidgetView: View {
    let entry: TaskEntry

    private var incompleteTodayCount: Int {
        entry.todayTasks.count + entry.overdueTasks.count
    }

    private var progress: Double {
        guard entry.totalCount > 0 else { return 0 }
        return Double(entry.completedCount) / Double(entry.totalCount)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetDesign.accentColor)
                Text("Taskweave")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.bottom, 8)

            Spacer()

            // Circular progress with count
            ZStack {
                // Background circle
                Circle()
                    .stroke(
                        Color.gray.opacity(0.2),
                        lineWidth: 6
                    )

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        WidgetDesign.accentColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)

                // Center content
                VStack(spacing: 2) {
                    Text("\(incompleteTodayCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(incompleteTodayCount == 1 ? "task" : "tasks")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            Spacer()

            // Footer stats
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(WidgetDesign.accentColor)
                Text("\(entry.completedCount)/\(entry.totalCount)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

#Preview(as: .systemSmall) {
    TaskweaveWidget()
} timeline: {
    TaskEntry.placeholder
}
