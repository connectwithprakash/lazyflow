import WidgetKit
import SwiftUI

/// Timeline entry containing task data for widget display
struct TaskEntry: TimelineEntry {
    let date: Date
    let todayTasks: [WidgetTask]
    let overdueTasks: [WidgetTask]
    let upcomingTasks: [WidgetTask]
    let completedCount: Int
    let totalCount: Int

    static var placeholder: TaskEntry {
        TaskEntry(
            date: Date(),
            todayTasks: [
                WidgetTask(id: UUID(), title: "Review project", priority: 4, isCompleted: false, dueDate: Date()),
                WidgetTask(id: UUID(), title: "Team meeting", priority: 3, isCompleted: false, dueDate: Date()),
                WidgetTask(id: UUID(), title: "Send report", priority: 2, isCompleted: false, dueDate: Date())
            ],
            overdueTasks: [],
            upcomingTasks: [],
            completedCount: 2,
            totalCount: 5
        )
    }

    static var empty: TaskEntry {
        TaskEntry(
            date: Date(),
            todayTasks: [],
            overdueTasks: [],
            upcomingTasks: [],
            completedCount: 0,
            totalCount: 0
        )
    }
}

/// Timeline provider for Taskweave widget
struct TaskTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> Void) {
        if context.isPreview {
            completion(TaskEntry.placeholder)
        } else {
            let entry = fetchTaskEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        let entry = fetchTaskEntry()

        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchTaskEntry() -> TaskEntry {
        let taskData = WidgetDataStore.loadTasks()

        if taskData.isEmpty {
            return TaskEntry.empty
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        var todayTasks: [WidgetTask] = []
        var overdueTasks: [WidgetTask] = []
        var upcomingTasks: [WidgetTask] = []
        var completedCount = 0
        var totalCount = 0

        for data in taskData {
            let task = data.toWidgetTask()
            totalCount += 1

            if data.isCompleted {
                completedCount += 1
                continue
            }

            if let dueDate = data.dueDate {
                if dueDate < startOfToday {
                    overdueTasks.append(task)
                } else if dueDate >= startOfToday && dueDate < endOfToday {
                    todayTasks.append(task)
                } else {
                    upcomingTasks.append(task)
                }
            }
        }

        // Sort by priority (higher first)
        todayTasks.sort { $0.priority > $1.priority }
        overdueTasks.sort { $0.priority > $1.priority }
        upcomingTasks.sort { $0.priority > $1.priority }

        return TaskEntry(
            date: now,
            todayTasks: todayTasks,
            overdueTasks: overdueTasks,
            upcomingTasks: upcomingTasks,
            completedCount: completedCount,
            totalCount: totalCount
        )
    }
}
