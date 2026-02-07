import SwiftUI
import Charts

/// Analytics dashboard view showing category and list insights
/// Part of Issue #130 - Category and List Analytics
struct AnalyticsView: View {
    @StateObject private var analyticsService = AnalyticsService()
    @State private var selectedPeriod: AnalyticsPeriod = .thisWeek

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Period Selector
                periodSelector

                // Overview Cards
                overviewSection

                // Category Distribution
                categoryDistributionSection

                // Completion Rates
                completionRatesSection

                // Work-Life Balance
                workLifeBalanceSection

                Spacer(minLength: DesignSystem.Spacing.xxl)
            }
            .padding(DesignSystem.Spacing.lg)
            // Force refresh when underlying task data changes
            .id(analyticsService.lastUpdated)
        }
        .background(Color.adaptiveBackground)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(AnalyticsPeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        let stats = analyticsService.getOverviewStats(for: selectedPeriod)

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader("Overview")

            HStack(spacing: DesignSystem.Spacing.md) {
                OverviewStatCard(
                    title: "Tasks",
                    value: "\(stats.totalTasks)",
                    subtitle: "\(stats.completedTasks) completed",
                    color: Color.Lazyflow.accent
                )

                OverviewStatCard(
                    title: "Completion",
                    value: "\(Int(stats.completionRate))%",
                    subtitle: stats.completionRate >= 70 ? "Great!" : "Keep going",
                    color: stats.completionRate >= 70 ? .green : .orange
                )

                if stats.overdueCount > 0 {
                    OverviewStatCard(
                        title: "Overdue",
                        value: "\(stats.overdueCount)",
                        subtitle: "Need attention",
                        color: .red
                    )
                }
            }
        }
    }

    // MARK: - Category Distribution Section

    private var categoryDistributionSection: some View {
        let categoryStats = analyticsService.getCategoryStats(for: selectedPeriod)

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader("Category Distribution")

            if categoryStats.isEmpty {
                emptyStateCard(message: "No tasks in this period")
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // Donut Chart (iOS 17+)
                    if #available(iOS 17.0, *) {
                        CategoryDonutChart(stats: categoryStats)
                            .frame(height: 200)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                    }

                    // Legend/Bar representation
                    ForEach(categoryStats.prefix(6)) { stat in
                        CategoryStatRow(stat: stat)
                    }

                    if categoryStats.count > 6 {
                        Text("+\(categoryStats.count - 6) more categories")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textTertiary)
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(Color.adaptiveSurface)
                .cornerRadius(DesignSystem.CornerRadius.large)
            }
        }
    }

    // MARK: - Completion Rates Section

    private var completionRatesSection: some View {
        let categoryStats = analyticsService.getCategoryStats(for: selectedPeriod)
            .filter { $0.totalCount > 0 }
            .sorted { $0.completionRate > $1.completionRate }

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader("Completion Rates")

            if categoryStats.isEmpty {
                emptyStateCard(message: "No tasks to analyze")
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(categoryStats) { stat in
                        CompletionRateRow(stat: stat)
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(Color.adaptiveSurface)
                .cornerRadius(DesignSystem.CornerRadius.large)
            }
        }
    }

    // MARK: - Work-Life Balance Section

    private var workLifeBalanceSection: some View {
        let balance = analyticsService.calculateWorkLifeBalance(for: selectedPeriod)

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader("Work-Life Balance")

            VStack(spacing: DesignSystem.Spacing.md) {
                // Balance bar
                HStack(spacing: 0) {
                    // Work portion
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: max(0, CGFloat(balance.workPercentage) / 100 * 280))

                    // Life portion
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: max(0, CGFloat(balance.lifePercentage) / 100 * 280))
                }
                .frame(height: 24)
                .cornerRadius(DesignSystem.CornerRadius.small)

                // Labels
                HStack {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Circle().fill(Color.blue).frame(width: 12, height: 12)
                        Text("Work \(Int(balance.workPercentage))%")
                            .font(DesignSystem.Typography.subheadline)
                    }

                    Spacer()

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Circle().fill(Color.green).frame(width: 12, height: 12)
                        Text("Life \(Int(balance.lifePercentage))%")
                            .font(DesignSystem.Typography.subheadline)
                    }
                }
                .foregroundColor(Color.Lazyflow.textSecondary)

                // Status
                HStack {
                    Image(systemName: balance.isBalanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(balance.isBalanced ? .green : .orange)
                    Text(balance.statusText)
                        .font(DesignSystem.Typography.footnote)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                // Target indicator
                Text("Target: 60% Work / 40% Life")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color.adaptiveSurface)
            .cornerRadius(DesignSystem.CornerRadius.large)
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.footnote)
                .fontWeight(.semibold)
                .foregroundColor(Color.Lazyflow.textSecondary)
                .textCase(.uppercase)
            Spacer()
        }
    }

    private func emptyStateCard(message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundColor(Color.Lazyflow.textTertiary)
            Text(message)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xl)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }
}

// MARK: - Supporting Components

struct OverviewStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textSecondary)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)

            Text(subtitle)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(Color.Lazyflow.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}

struct CategoryStatRow: View {
    let stat: CategoryStats

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(stat.category.color)
                .frame(width: 12, height: 12)

            Text(stat.category.displayName)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textPrimary)

            Spacer()

            Text("\(stat.totalCount) tasks")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textSecondary)
        }
    }
}

struct CompletionRateRow: View {
    let stat: CategoryStats

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: stat.category.iconName)
                        .foregroundColor(stat.category.color)
                    Text(stat.category.displayName)
                        .font(DesignSystem.Typography.subheadline)
                }

                Spacer()

                Text("\(Int(stat.completionRate))%")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(stat.completionRate >= 70 ? .green : (stat.completionRate >= 40 ? .orange : .red))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    Rectangle()
                        .fill(stat.category.color)
                        .frame(width: geometry.size.width * CGFloat(stat.completionRate / 100), height: 6)
                }
                .cornerRadius(3)
            }
            .frame(height: 6)

            Text("\(stat.completedCount)/\(stat.totalCount) completed")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(Color.Lazyflow.textTertiary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Donut Chart (iOS 17+)

@available(iOS 17.0, *)
struct CategoryDonutChart: View {
    let stats: [CategoryStats]

    var body: some View {
        Chart(stats) { stat in
            SectorMark(
                angle: .value("Tasks", stat.totalCount),
                innerRadius: .ratio(0.6),
                angularInset: 2
            )
            .foregroundStyle(stat.category.color)
            .cornerRadius(4)
        }
        .chartLegend(.hidden)
        .accessibilityLabel("Category distribution chart")
        .accessibilityValue(generateAccessibilityValue())
    }

    private func generateAccessibilityValue() -> String {
        stats.map { "\($0.category.displayName): \($0.totalCount) tasks" }.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AnalyticsView()
    }
}
