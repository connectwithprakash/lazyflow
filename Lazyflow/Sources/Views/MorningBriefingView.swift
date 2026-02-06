import SwiftUI

/// Morning briefing view showing yesterday's recap, today's plan, and weekly stats
struct MorningBriefingView: View {
    @StateObject private var summaryService = DailySummaryService.shared
    @State private var briefing: MorningBriefingData?
    @State private var isLoading = false
    @State private var didRecordImpression = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    loadingView
                } else if let briefing = briefing {
                    briefingContent(briefing)
                } else {
                    emptyStateView
                }
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("Good Morning")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: toolbarContent)
        }
        .task {
            await loadBriefing()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    _Concurrency.Task {
                        await refreshBriefing()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)

                // Show Regenerate AI when briefing data exists (even if AI failed previously)
                if briefing != nil {
                    Button {
                        _Concurrency.Task {
                            await regenerateAI()
                        }
                    } label: {
                        Image(systemName: "sparkles")
                    }
                    .disabled(isLoading)
                }
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Done") {
                dismiss()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Preparing your morning briefing...")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            Image(systemName: "sun.max.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("Ready to start your day!")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textSecondary)
            Text("Add some tasks to see your morning briefing")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 400)
        .padding()
    }

    // MARK: - Briefing Content

    private func briefingContent(_ briefing: MorningBriefingData) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Greeting Card
            greetingCard(briefing)

            // Yesterday Recap Card
            if briefing.yesterdayCompleted > 0 || briefing.yesterdayPlanned > 0 {
                yesterdayRecapCard(briefing)
            }

            // Today's Plan Card
            todayPlanCard(briefing)

            // Today's Schedule Card (if calendar access granted)
            if let schedule = briefing.scheduleSummary {
                scheduleCard(schedule)
            }

            // Weekly Progress Card
            weeklyProgressCard(briefing.weeklyStats)

            // Today's Priority Tasks
            if !briefing.todayTasks.isEmpty {
                priorityTasksSection(briefing.todayTasks)
            }

            // Motivational Message
            if let motivation = briefing.motivationalMessage {
                motivationCard(motivation)
            }

            Spacer(minLength: DesignSystem.Spacing.xxxl)
        }
        .padding()
    }

    // MARK: - Greeting Card

    private func greetingCard(_ briefing: MorningBriefingData) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 24))
                Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            if let summary = briefing.aiSummary {
                Text(summary)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(Color.Lazyflow.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let todayFocus = briefing.todayFocus {
                Divider()
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "target")
                        .foregroundColor(Color.Lazyflow.accent)
                    Text(todayFocus)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Lazyflow.textPrimary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    // MARK: - Yesterday Recap Card

    private func yesterdayRecapCard(_ briefing: MorningBriefingData) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(Color.Lazyflow.accent)
                Text("Yesterday")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)
            }

            HStack(spacing: DesignSystem.Spacing.xxxl) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("\(briefing.yesterdayCompleted)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.Lazyflow.textPrimary)
                    Text("Completed")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("\(briefing.yesterdayCompletionPercentage)%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(briefing.wasYesterdayProductive ? .green : Color.Lazyflow.textPrimary)
                    Text("Completion")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                if let category = briefing.yesterdayTopCategory {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 24, height: 24)
                        Text(category.displayName)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    // MARK: - Today's Plan Card

    private func todayPlanCard(_ briefing: MorningBriefingData) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(Color.Lazyflow.accent)
                Text("Today's Plan")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)
            }

            HStack(spacing: DesignSystem.Spacing.xl) {
                statItem(
                    value: "\(briefing.todayTasks.count)",
                    label: "Tasks",
                    icon: "checklist",
                    color: Color.Lazyflow.accent
                )

                if briefing.todayHighPriority > 0 {
                    statItem(
                        value: "\(briefing.todayHighPriority)",
                        label: "High Priority",
                        icon: "exclamationmark.circle.fill",
                        color: .orange
                    )
                }

                if briefing.todayOverdue > 0 {
                    statItem(
                        value: "\(briefing.todayOverdue)",
                        label: "Overdue",
                        icon: "clock.badge.exclamationmark.fill",
                        color: .red
                    )
                }

                if briefing.todayEstimatedMinutes > 0 {
                    statItem(
                        value: briefing.formattedTodayTime,
                        label: "Est. Time",
                        icon: "clock.fill",
                        color: .blue
                    )
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(Color.Lazyflow.textPrimary)

            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(Color.Lazyflow.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - Schedule Card

    private func scheduleCard(_ schedule: ScheduleSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.purple)
                Text("Today's Schedule")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)
            }

            if schedule.hasMeetings {
                // Meeting summary
                HStack(spacing: DesignSystem.Spacing.xl) {
                    statItem(
                        value: "\(schedule.meetingCount)",
                        label: "Meetings",
                        icon: "person.2.fill",
                        color: .purple
                    )

                    statItem(
                        value: schedule.formattedMeetingTime,
                        label: "In Meetings",
                        icon: "clock.fill",
                        color: .purple
                    )

                    if schedule.hasSignificantFreeBlock {
                        statItem(
                            value: schedule.formattedFreeBlock,
                            label: "Free Block",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    }
                }

                // Next event
                if let nextEvent = schedule.nextEvent {
                    Divider()
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next: \(nextEvent.title)")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(Color.Lazyflow.textPrimary)
                                .lineLimit(1)
                            Text(nextEvent.formattedTimeRange)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                        Spacer()
                    }
                }
            } else {
                // No meetings today
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No meetings today")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(Color.Lazyflow.textPrimary)
                    Spacer()
                    Text("\(schedule.formattedFreeBlock) free")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(.green)
                }
            }

            // All-day events
            if !schedule.allDayEvents.isEmpty {
                Divider()
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    Text("All day: \(schedule.allDayEvents.map { $0.title }.joined(separator: ", "))")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    // MARK: - Weekly Progress Card

    private func weeklyProgressCard(_ stats: WeeklyStats) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(Color.Lazyflow.accent)
                Text("This Week")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)
                Spacer()
                Text(stats.weeklyInsight)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.accent)
            }

            HStack(spacing: DesignSystem.Spacing.xxxl) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("\(stats.tasksCompletedThisWeek)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color.Lazyflow.textPrimary)
                    Text("Completed")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(stats.formattedCompletionRate)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(stats.averageCompletionRate >= 70 ? .green : Color.Lazyflow.textPrimary)
                    Text("Avg Rate")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                if stats.hasStreak {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 16))
                            Text("\(stats.currentStreak)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Color.Lazyflow.textPrimary)
                        }
                        Text("Streak")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                }
            }

            if let bestDay = stats.mostProductiveDay {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                    Text("Best day: \(bestDay)")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textTertiary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    // MARK: - Priority Tasks Section

    private func priorityTasksSection(_ tasks: [TaskBriefingSummary]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "list.bullet.clipboard.fill")
                    .foregroundColor(Color.Lazyflow.accent)
                Text("Today's Priorities")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)
                Spacer()
                Text("\(tasks.count)")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            ForEach(tasks.prefix(5)) { task in
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Priority indicator
                    Circle()
                        .fill(priorityColor(task.priority))
                        .frame(width: 8, height: 8)

                    // Task title
                    Text(task.title)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Lazyflow.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Due time or duration
                    if let dueTime = task.formattedDueTime {
                        Text(dueTime)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(task.isOverdue ? .red : Color.Lazyflow.textTertiary)
                    } else if let duration = task.formattedDuration {
                        Text(duration)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textTertiary)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
            }

            if tasks.count > 5 {
                Text("+ \(tasks.count - 5) more tasks")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .none: return Color.Lazyflow.textTertiary
        }
    }

    // MARK: - Motivation Card

    private func motivationCard(_ message: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "sparkles")
                .foregroundColor(.yellow)
                .font(.system(size: 24))

            Text(message)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    // MARK: - Load Briefing

    private func loadBriefing() async {
        isLoading = true
        briefing = await summaryService.generateMorningBriefing()
        isLoading = false
        recordImpressionIfNeeded()
    }

    private func refreshBriefing() async {
        isLoading = true
        didRecordImpression = false  // Reset before reloading
        briefing = await summaryService.forceRefreshMorningBriefing()
        isLoading = false
        recordImpressionIfNeeded()
    }

    private func regenerateAI() async {
        guard let currentBriefing = briefing else { return }
        isLoading = true
        didRecordImpression = false  // Reset for new AI content
        briefing = await summaryService.regenerateMorningBriefingAI(for: currentBriefing)
        isLoading = false
        recordImpressionIfNeeded()
    }

    private func recordImpressionIfNeeded() {
        if summaryService.recordImpressionIfNeeded(
            aiSummary: briefing?.aiSummary,
            alreadyRecorded: didRecordImpression
        ) {
            didRecordImpression = true
        }
    }
}

// MARK: - Preview

#Preview {
    MorningBriefingView()
}
