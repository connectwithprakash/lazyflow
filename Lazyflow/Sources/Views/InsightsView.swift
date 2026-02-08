import SwiftUI

/// Hub view for Insights tab containing analytics, history, and AI summaries
/// Part of navigation restructure (Issue #110)
struct InsightsView: View {
    /// Navigation path for deep linking (optional, used on iPhone)
    @Binding var navigationPath: NavigationPath
    @State private var showMorningBriefing = false
    @State private var showDailySummary = false
    @State private var showAIQuality = false
    @StateObject private var summaryService = DailySummaryService.shared

    init(navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        _navigationPath = navigationPath
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // MARK: - AI Insights Section
                    sectionHeader("AI Insights")

                    // Morning Briefing Card
                    Button {
                        showMorningBriefing = true
                    } label: {
                        InsightsCard(
                            icon: "sun.max.fill",
                            iconColor: .orange,
                            title: "Morning Briefing",
                            subtitle: "Yesterday's recap & today's plan"
                        )
                    }
                    .accessibilityIdentifier("MorningBriefingCard")

                    // Daily Summary Card
                    Button {
                        showDailySummary = true
                    } label: {
                        InsightsCardWithBadge(
                            icon: "chart.bar.doc.horizontal",
                            iconColor: Color.Lazyflow.accent,
                            title: "Daily Summary",
                            subtitle: "Track your productivity",
                            badgeIcon: summaryService.streakData.currentStreak > 0 ? "flame.fill" : nil,
                            badgeColor: .orange,
                            badgeText: summaryService.streakData.currentStreak > 0 ? "\(summaryService.streakData.currentStreak)" : nil
                        )
                    }
                    .accessibilityIdentifier("DailySummaryCard")

                    // AI Quality Card
                    Button {
                        showAIQuality = true
                    } label: {
                        InsightsCard(
                            icon: "sparkles",
                            iconColor: Color.Lazyflow.success,
                            title: "AI Quality",
                            subtitle: "Correction & refinement rates"
                        )
                    }
                    .accessibilityIdentifier("AIQualityCard")

                    // MARK: - History Section
                    sectionHeader("Activity")
                        .padding(.top, DesignSystem.Spacing.sm)

                    // History Card
                    NavigationLink {
                        HistoryView()
                    } label: {
                        InsightsCard(
                            icon: "clock.arrow.circlepath",
                            iconColor: Color.Lazyflow.textSecondary,
                            title: "History",
                            subtitle: "View completed tasks"
                        )
                    }
                    .accessibilityIdentifier("HistoryCard")

                    // MARK: - Analytics Section
                    sectionHeader("Analytics")
                        .padding(.top, DesignSystem.Spacing.sm)

                    // Analytics Card
                    NavigationLink {
                        AnalyticsView()
                    } label: {
                        InsightsCard(
                            icon: "chart.pie.fill",
                            iconColor: .purple,
                            title: "Analytics",
                            subtitle: "Category & list insights"
                        )
                    }
                    .accessibilityIdentifier("AnalyticsCard")

                    Spacer(minLength: DesignSystem.Spacing.xxl)
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showMorningBriefing) {
                MorningBriefingView()
            }
            .sheet(isPresented: $showDailySummary) {
                DailySummaryView()
            }
            .sheet(isPresented: $showAIQuality) {
                AIQualityView()
            }
            .onAppear {
                // Preload insights data in background
                summaryService.preloadInsightsData()
            }
            .navigationDestination(for: ContentView.InsightsDestination.self) { destination in
                switch destination {
                case .history:
                    HistoryView()
                }
            }
        }
    }

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
}

// MARK: - Insights Card Component

struct InsightsCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Text(subtitle)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.Lazyflow.textTertiary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }
}

// MARK: - Insights Card with Badge Component

struct InsightsCardWithBadge: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let badgeIcon: String?
    let badgeColor: Color
    let badgeText: String?

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Text(subtitle)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            Spacer()

            // Badge (if present)
            if let badgeIcon = badgeIcon, let badgeText = badgeText {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: badgeIcon)
                        .foregroundColor(badgeColor)
                    Text(badgeText)
                        .font(DesignSystem.Typography.footnote)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.Lazyflow.textTertiary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }
}

// MARK: - Preview

#Preview {
    InsightsView(navigationPath: .constant(NavigationPath()))
}
