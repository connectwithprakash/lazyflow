import SwiftUI

struct AIQualityView: View {
    @StateObject private var viewModel = AIQualityViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod: TimePeriod = .sevenDays

    enum TimePeriod: String, CaseIterable, Identifiable {
        case sevenDays = "7 Days"
        case thirtyDays = "30 Days"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    periodPicker

                    if viewModel.hasData {
                        metricsContent
                    } else {
                        emptyState
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("AI Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { viewModel.refresh() }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Time Period", selection: $selectedPeriod) {
            ForEach(TimePeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Metrics Content

    private var metricsContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Primary metric: Acceptance Rate
            primaryMetricCard

            // Detail metrics
            HStack(spacing: DesignSystem.Spacing.md) {
                metricCard(
                    title: "Corrections",
                    value: correctionRate,
                    count: correctionCount,
                    icon: "pencil.line",
                    color: .orange,
                    description: "How often you edited AI suggestions"
                )

                metricCard(
                    title: "Regenerations",
                    value: refinementRate,
                    count: refinementCount,
                    icon: "arrow.clockwise",
                    color: .purple,
                    description: "How often you tapped Regenerate"
                )
            }

            // Impressions info
            impressionsCard

            // Explanation
            explanationCard
        }
    }

    // MARK: - Primary Metric

    private var primaryMetricCard: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(Color.Lazyflow.textTertiary.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: acceptanceRateValue)
                    .stroke(acceptanceColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: acceptanceRateValue)

                VStack(spacing: 2) {
                    Text(acceptanceRate)
                        .font(DesignSystem.Typography.title1)
                        .fontWeight(.bold)
                        .foregroundColor(Color.Lazyflow.textPrimary)

                    Text("accepted")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }
            }

            Text("AI Acceptance Rate")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textPrimary)

            Text("Percentage of AI suggestions used as-is")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.lg)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    // MARK: - Detail Metric Card

    private func metricCard(
        title: String,
        value: String,
        count: Int,
        icon: String,
        color: Color,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)

                Text(title)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            Text(value)
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.Lazyflow.textPrimary)

            Text("\(count) total")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textTertiary)

            Text(description)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(Color.Lazyflow.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    // MARK: - Impressions Card

    private var impressionsCard: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "eye.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.Lazyflow.accent)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text("AI Impressions")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Text("\(impressionCount) times AI suggestions were shown")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    // MARK: - Explanation Card

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color.Lazyflow.accent)
                Text("What do these metrics mean?")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.Lazyflow.textPrimary)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                explanationRow(
                    term: "Acceptance Rate",
                    definition: "How often you use AI suggestions without changes. Higher is better."
                )
                explanationRow(
                    term: "Correction Rate",
                    definition: "How often you edit AI-suggested categories, priorities, or durations."
                )
                explanationRow(
                    term: "Regeneration Rate",
                    definition: "How often you tap Regenerate on Morning Briefings or Daily Summaries."
                )
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private func explanationRow(term: String, definition: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(term)
                .font(DesignSystem.Typography.caption1)
                .fontWeight(.semibold)
                .foregroundColor(Color.Lazyflow.textPrimary)
            Text(definition)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(Color.Lazyflow.textSecondary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(Color.Lazyflow.textTertiary)

            Text("No AI data yet")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textPrimary)

            Text("As you use AI features like task suggestions, Morning Briefings, and Daily Summaries, quality metrics will appear here.")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.xxl)
    }

    // MARK: - Computed Properties (period-aware)

    private var acceptanceRate: String {
        selectedPeriod == .sevenDays ? viewModel.formattedAcceptanceRate7d : viewModel.formattedAcceptanceRate30d
    }

    private var acceptanceRateValue: Double {
        selectedPeriod == .sevenDays ? viewModel.acceptanceRate7d : viewModel.acceptanceRate30d
    }

    private var acceptanceColor: Color {
        let rate = acceptanceRateValue
        if rate >= 0.8 { return Color.Lazyflow.success }
        if rate >= 0.5 { return .orange }
        return Color.Lazyflow.error
    }

    private var correctionRate: String {
        selectedPeriod == .sevenDays ? viewModel.formattedCorrectionRate7d : viewModel.formattedCorrectionRate30d
    }

    private var correctionCount: Int {
        selectedPeriod == .sevenDays ? viewModel.correctionCount7d : viewModel.correctionCount30d
    }

    private var refinementRate: String {
        selectedPeriod == .sevenDays ? viewModel.formattedRefinementRate7d : viewModel.formattedRefinementRate30d
    }

    private var refinementCount: Int {
        selectedPeriod == .sevenDays ? viewModel.refinementCount7d : viewModel.refinementCount30d
    }

    private var impressionCount: Int {
        selectedPeriod == .sevenDays ? viewModel.impressionCount7d : viewModel.impressionCount30d
    }
}

#Preview {
    AIQualityView()
}
