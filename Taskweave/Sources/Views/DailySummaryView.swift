import SwiftUI

/// Daily summary view showing productivity stats, streak, and AI-generated recap
struct DailySummaryView: View {
    @StateObject private var summaryService = DailySummaryService.shared
    @State private var summary: DailySummaryData?
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    loadingView
                } else if let summary = summary {
                    summaryContent(summary)
                } else {
                    emptyStateView
                }
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("Daily Summary")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: toolbarContent)
        }
        .task {
            await loadSummary()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                _Concurrency.Task {
                    await refreshSummary()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(isLoading)
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
            Text("Generating your summary...")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Taskweave.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(Color.Taskweave.textTertiary)
            Text("No tasks completed today")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Taskweave.textSecondary)
            Text("Complete some tasks to see your daily summary")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Taskweave.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 400)
        .padding()
    }

    // MARK: - Summary Content

    private func summaryContent(_ summary: DailySummaryData) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Streak Card
            StreakCard(streakData: summaryService.streakData)

            // Progress Section
            progressSection(summary)

            // AI Summary Card
            if let aiSummary = summary.aiSummary {
                aiSummaryCard(aiSummary, encouragement: summary.encouragement)
            } else if let encouragement = summary.encouragement {
                encouragementCard(encouragement)
            }

            // Completed Tasks
            if !summary.completedTasks.isEmpty {
                completedTasksSection(summary.completedTasks)
            }

            // Category Breakdown
            if let topCategory = summary.topCategory {
                categorySection(topCategory, tasks: summary.completedTasks)
            }

            // Time Worked
            if summary.totalMinutesWorked > 0 {
                timeWorkedSection(summary)
            }

            Spacer(minLength: DesignSystem.Spacing.xxxl)
        }
        .padding()
    }

    // MARK: - Progress Section

    private func progressSection(_ summary: DailySummaryData) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.Taskweave.textTertiary.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(summary.completionPercentage) / 100)
                    .stroke(
                        Color.Taskweave.accent,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(summary.completionPercentage)%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.Taskweave.textPrimary)
                    Text("complete")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Taskweave.textSecondary)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.md)

            // Stats Row
            HStack(spacing: DesignSystem.Spacing.xxxl) {
                statItem(
                    value: "\(summary.tasksCompleted)",
                    label: "Completed",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                statItem(
                    value: "\(summary.totalTasksPlanned)",
                    label: "Planned",
                    icon: "calendar",
                    color: Color.Taskweave.accent
                )

                statItem(
                    value: summary.formattedTimeWorked,
                    label: "Time",
                    icon: "clock.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Color.Taskweave.textPrimary)

            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(Color.Taskweave.textSecondary)
        }
    }

    // MARK: - AI Summary Card

    private func aiSummaryCard(_ summary: String, encouragement: String?) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(Color.Taskweave.accent)
                Text("AI Summary")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Taskweave.textPrimary)
            }

            Text(summary)
                .font(DesignSystem.Typography.body)
                .foregroundColor(Color.Taskweave.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let encouragement = encouragement {
                Divider()

                Text(encouragement)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.accent)
                    .italic()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private func encouragementCard(_ encouragement: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "heart.fill")
                .foregroundColor(.pink)
                .font(.system(size: 24))

            Text(encouragement)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Taskweave.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    // MARK: - Completed Tasks Section

    private func completedTasksSection(_ tasks: [CompletedTaskSummary]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Completed Tasks")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Taskweave.textPrimary)
                Spacer()
                Text("\(tasks.count)")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.textSecondary)
            }

            ForEach(tasks.prefix(10)) { task in
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Circle()
                        .fill(task.category.color)
                        .frame(width: 8, height: 8)

                    Text(task.title)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Taskweave.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(task.completedAt.formatted(date: .omitted, time: .shortened))
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Taskweave.textTertiary)
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
            }

            if tasks.count > 10 {
                Text("+ \(tasks.count - 10) more")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Taskweave.textTertiary)
            }
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    // MARK: - Category Section

    private func categorySection(_ topCategory: TaskCategory, tasks: [CompletedTaskSummary]) -> some View {
        let categoryCounts = Dictionary(grouping: tasks, by: { $0.category })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(Color.Taskweave.accent)
                Text("Categories")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Taskweave.textPrimary)
            }

            ForEach(categoryCounts, id: \.key) { category, count in
                HStack {
                    Circle()
                        .fill(category.color)
                        .frame(width: 12, height: 12)

                    Text(category.displayName)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Taskweave.textPrimary)

                    Spacer()

                    Text("\(count)")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Taskweave.textSecondary)
                }
            }
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    // MARK: - Time Worked Section

    private func timeWorkedSection(_ summary: DailySummaryData) -> some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(.orange)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text("Time Worked")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Taskweave.textSecondary)
                Text(summary.formattedTimeWorked)
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(Color.Taskweave.textPrimary)
            }

            Spacer()

            if summary.totalMinutesWorked >= 60 {
                Text("Great focus!")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Taskweave.accent)
            }
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    // MARK: - Load Summary

    private func loadSummary() async {
        isLoading = true

        // Check if we already have today's summary
        if let existing = summaryService.getSummary(for: Date()) {
            summary = existing
            isLoading = false
            return
        }

        // Generate new summary
        summary = await summaryService.generateSummary(for: Date())
        isLoading = false
    }

    private func refreshSummary() async {
        isLoading = true
        // Force regenerate - ignores cache
        summary = await summaryService.generateSummary(for: Date())
        isLoading = false
    }
}

// MARK: - Streak Card Component

struct StreakCard: View {
    let streakData: StreakData

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Flame Icon
            ZStack {
                Circle()
                    .fill(streakColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: streakData.currentStreak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 28))
                    .foregroundColor(streakColor)
            }

            // Streak Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xs) {
                    Text("\(streakData.currentStreak)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Color.Taskweave.textPrimary)
                    Text("day streak")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Taskweave.textSecondary)
                }

                if streakData.currentStreak > 0 {
                    if streakData.isAtMilestone {
                        milestoneLabel
                    } else if let daysToNext = streakData.daysToNextMilestone {
                        Text("\(daysToNext) days to next milestone")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Taskweave.textTertiary)
                    }
                } else {
                    Text("Start your streak today!")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Taskweave.textTertiary)
                }
            }

            Spacer()

            // Longest Streak Badge
            if streakData.longestStreak > 0 {
                VStack(spacing: 2) {
                    Text("Best")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(Color.Taskweave.textTertiary)
                    Text("\(streakData.longestStreak)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.Taskweave.accent)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(Color.Taskweave.accent.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private var streakColor: Color {
        if streakData.currentStreak >= 30 {
            return .orange
        } else if streakData.currentStreak >= 7 {
            return .yellow
        } else if streakData.currentStreak > 0 {
            return Color.Taskweave.accent
        } else {
            return Color.Taskweave.textTertiary
        }
    }

    private var milestoneLabel: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
            Text("Milestone reached!")
        }
        .font(DesignSystem.Typography.caption1)
        .foregroundColor(.orange)
    }
}

// MARK: - Preview

#Preview {
    DailySummaryView()
}
