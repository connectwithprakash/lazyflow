import SwiftUI
import Charts

/// Analytics dashboard view showing category and list insights
/// Part of Issue #130 - Category and List Analytics
struct AnalyticsView: View {
    @StateObject private var analyticsService = AnalyticsService()
    @State private var selectedPeriod: AnalyticsPeriod = .thisWeek
    /// Triggers view refresh when task data changes, without resetting scroll
    @State private var refreshTrigger = Date()

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

                // List Health
                listHealthSection

                // Stale Lists
                staleListsSection

                Spacer(minLength: DesignSystem.Spacing.xxl)
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(Color.adaptiveBackground)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .onReceive(analyticsService.$lastUpdated) { newValue in
            // Update local state to trigger view refresh without recreating scroll container
            refreshTrigger = newValue
        }
    }

    // MARK: - Computed Data (refreshed via refreshTrigger)

    private var overviewStats: OverviewStats {
        _ = refreshTrigger // Reference to ensure recomputation
        return analyticsService.getOverviewStats(for: selectedPeriod)
    }

    private var unifiedCategoryStats: [UnifiedCategoryStats] {
        _ = refreshTrigger
        return analyticsService.getUnifiedCategoryStats(for: selectedPeriod)
    }

    private var workLifeBalance: WorkLifeBalance {
        _ = refreshTrigger
        return analyticsService.calculateWorkLifeBalance(for: selectedPeriod)
    }

    private var listHealthData: [(list: TaskList, health: ListHealth)] {
        _ = refreshTrigger
        return analyticsService.getAllListHealth()
    }

    private var staleLists: [TaskList] {
        _ = refreshTrigger
        return analyticsService.getStaleLists()
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
        let stats = overviewStats

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
        let stats = unifiedCategoryStats

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader("Category Distribution")

            if stats.isEmpty {
                emptyStateCard(message: "No tasks in this period")
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // Donut Chart (iOS 17+)
                    if #available(iOS 17.0, *) {
                        UnifiedCategoryDonutChart(stats: stats)
                            .frame(height: 200)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                    }

                    // Legend/Bar representation
                    ForEach(stats.prefix(6)) { stat in
                        UnifiedCategoryStatRow(stat: stat)
                    }

                    if stats.count > 6 {
                        Text("+\(stats.count - 6) more categories")
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
        let filteredStats = unifiedCategoryStats
            .filter { $0.totalCount > 0 }
            .sorted { $0.completionRate > $1.completionRate }

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader("Completion Rates")

            if filteredStats.isEmpty {
                emptyStateCard(message: "No tasks to analyze")
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(filteredStats) { stat in
                        UnifiedCompletionRateRow(stat: stat)
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
        let balance = workLifeBalance

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

    // MARK: - List Health Section

    private var listHealthSection: some View {
        let lists = listHealthData

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader("List Health")

            if lists.isEmpty {
                emptyStateCard(message: "No lists to analyze")
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(lists.prefix(5), id: \.list.id) { item in
                        ListHealthRow(list: item.list, health: item.health)
                    }

                    if lists.count > 5 {
                        Text("+\(lists.count - 5) more lists")
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

    // MARK: - Stale Lists Section

    private var staleListsSection: some View {
        let stale = staleLists

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if !stale.isEmpty {
                sectionHeader("Needs Attention")

                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(stale) { list in
                        StaleListRow(list: list)
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.large)
            }
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

// MARK: - Unified Category Components (supports custom categories)

struct UnifiedCategoryStatRow: View {
    let stat: UnifiedCategoryStats

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(stat.color)
                .frame(width: 12, height: 12)

            HStack(spacing: DesignSystem.Spacing.xxs) {
                Text(stat.displayName)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                if stat.isCustom {
                    Image(systemName: "person.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color.Lazyflow.textTertiary)
                }
            }

            Spacer()

            Text("\(stat.totalCount) tasks")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textSecondary)
        }
    }
}

struct UnifiedCompletionRateRow: View {
    let stat: UnifiedCategoryStats

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: stat.iconName)
                        .foregroundColor(stat.color)
                    Text(stat.displayName)
                        .font(DesignSystem.Typography.subheadline)
                    if stat.isCustom {
                        Image(systemName: "person.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color.Lazyflow.textTertiary)
                    }
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
                        .fill(stat.color)
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

// MARK: - List Health Components

struct ListHealthRow: View {
    let list: TaskList
    let health: ListHealth

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // List color indicator
            Circle()
                .fill(list.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(list.name)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text("\(Int(health.completionRate))% done")
                        .font(DesignSystem.Typography.caption2)

                    if health.overdueCount > 0 {
                        Text("• \(health.overdueCount) overdue")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.orange)
                    }

                    Text("• \(String(format: "%.1f", health.velocity))/wk")
                        .font(DesignSystem.Typography.caption2)
                }
                .foregroundColor(Color.Lazyflow.textTertiary)
            }

            Spacer()

            // Health score badge
            Text(health.healthLevel.rawValue)
                .font(DesignSystem.Typography.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .background(health.healthLevel.color.opacity(0.2))
                .foregroundColor(health.healthLevel.color)
                .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

struct StaleListRow: View {
    let list: TaskList

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(list.name)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Text("No activity in 14+ days")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }

            Spacer()
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

@available(iOS 17.0, *)
struct UnifiedCategoryDonutChart: View {
    let stats: [UnifiedCategoryStats]

    var body: some View {
        Chart(stats) { stat in
            SectorMark(
                angle: .value("Tasks", stat.totalCount),
                innerRadius: .ratio(0.6),
                angularInset: 2
            )
            .foregroundStyle(stat.color)
            .cornerRadius(4)
        }
        .chartLegend(.hidden)
        .accessibilityLabel("Category distribution chart")
        .accessibilityValue(generateAccessibilityValue())
    }

    private func generateAccessibilityValue() -> String {
        stats.map { "\($0.displayName): \($0.totalCount) tasks" }.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AnalyticsView()
    }
}
