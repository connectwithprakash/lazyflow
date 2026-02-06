import SwiftUI

/// Hub view for Me/Profile tab containing lists, categories, and settings
/// Part of navigation restructure (Issue #110)
struct ProfileView: View {
    /// Navigation path for deep linking (optional, used on iPhone)
    @Binding var navigationPath: NavigationPath

    init(navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        _navigationPath = navigationPath
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // MARK: - Organize Section
                    sectionHeader("Organize")

                    // Lists Card
                    NavigationLink {
                        ListsView()
                    } label: {
                        ProfileCard(
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
                        ProfileCard(
                            icon: "tag.fill",
                            iconColor: .purple,
                            title: "Categories",
                            subtitle: "Browse tasks by category"
                        )
                    }
                    .accessibilityIdentifier("CategoriesCard")

                    // MARK: - System Section
                    sectionHeader("System")
                        .padding(.top, DesignSystem.Spacing.sm)

                    // Settings Card
                    NavigationLink {
                        SettingsView()
                    } label: {
                        ProfileCard(
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
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: ContentView.ProfileDestination.self) { destination in
                switch destination {
                case .lists:
                    ListsView()
                case .settings:
                    SettingsView()
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

// MARK: - Profile Card Component

struct ProfileCard: View {
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

// MARK: - Preview

#Preview {
    ProfileView(navigationPath: .constant(NavigationPath()))
}
