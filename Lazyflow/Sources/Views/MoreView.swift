import SwiftUI

/// Hub view for secondary features (Lists, Insights, Settings)
/// Designed as a clean hub rather than a boring overflow menu
struct MoreView: View {
    @State private var showMorningBriefing = false
    @State private var showDailySummary = false
    @StateObject private var summaryService = DailySummaryService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // MARK: - Organize Section
                    sectionHeader("Organize")

                    // Lists Card
                    NavigationLink {
                        ListsView()
                    } label: {
                        MoreCard(
                            icon: "folder.fill",
                            iconColor: Color.Lazyflow.accent,
                            title: "Lists",
                            subtitle: "Organize your tasks"
                        )
                    }
                    .accessibilityIdentifier("ListsCard")

                    // Categories Card
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        MoreCard(
                            icon: "tag.fill",
                            iconColor: .purple,
                            title: "Categories",
                            subtitle: "Browse tasks by category"
                        )
                    }
                    .accessibilityIdentifier("CategoriesCard")

                    // MARK: - Insights Section
                    sectionHeader("Insights")
                        .padding(.top, DesignSystem.Spacing.sm)

                    // Morning Briefing Card
                    Button {
                        showMorningBriefing = true
                    } label: {
                        MoreCard(
                            icon: "sun.max.fill",
                            iconColor: .orange,
                            title: "Morning Briefing",
                            subtitle: "Yesterday's recap & today's plan"
                        )
                    }

                    // Daily Summary Card
                    Button {
                        showDailySummary = true
                    } label: {
                        MoreCardWithBadge(
                            icon: "chart.bar.doc.horizontal",
                            iconColor: Color.Lazyflow.accent,
                            title: "Daily Summary",
                            subtitle: "Track your productivity",
                            badgeIcon: summaryService.streakData.currentStreak > 0 ? "flame.fill" : nil,
                            badgeColor: .orange,
                            badgeText: summaryService.streakData.currentStreak > 0 ? "\(summaryService.streakData.currentStreak)" : nil
                        )
                    }

                    // MARK: - System Section
                    sectionHeader("System")
                        .padding(.top, DesignSystem.Spacing.sm)

                    // Settings Card
                    NavigationLink {
                        SettingsView()
                    } label: {
                        MoreCard(
                            icon: "gear",
                            iconColor: Color.Lazyflow.textSecondary,
                            title: "Settings",
                            subtitle: "Customize your experience"
                        )
                    }
                    .accessibilityIdentifier("SettingsCard")

                    Spacer(minLength: DesignSystem.Spacing.xxl)

                    // App info footer
                    appInfoFooter
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showMorningBriefing) {
                MorningBriefingView()
            }
            .sheet(isPresented: $showDailySummary) {
                DailySummaryView()
            }
            .onAppear {
                // Preload insights data in background so it's ready when user taps
                summaryService.preloadInsightsData()
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

    private var appInfoFooter: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image("AppIconPreview")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .opacity(0.8)

            Text("Lazyflow")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textSecondary)

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("Version \(version) (\(build))")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DesignSystem.Spacing.xl)
    }
}

// MARK: - More Card Component

struct MoreCard: View {
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

// MARK: - More Card with Badge Component

struct MoreCardWithBadge: View {
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
    MoreView()
}
