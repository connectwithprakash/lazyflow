import SwiftUI
import LazyflowCore
import LazyflowUI

/// Hub view for Me/Profile tab with inline organize and settings cards
/// Part of navigation restructure (Issue #285)
struct ProfileView: View {
    /// Navigation path for deep linking (optional, used on iPhone)
    @Binding var navigationPath: NavigationPath
    @State private var searchText = ""

    init(navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        _navigationPath = navigationPath
    }

    private var trimmedSearch: String { searchText.trimmingCharacters(in: .whitespaces) }
    private var isSearching: Bool { !trimmedSearch.isEmpty }

    private var showLists: Bool { matchesSearch("Lists", "Organize your tasks") }
    private var showCategories: Bool { matchesSearch("Categories", "Browse tasks by category") }
    private var filteredRoutes: [SettingsRoute] {
        SettingsRoute.allCases.filter { $0.matches(trimmedSearch) }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // MARK: - Organize Section
                    if showLists || showCategories {
                        sectionHeader("Organize")

                        if showLists {
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
                            .accessibilityLabel("Lists: Organize your tasks")
                        }

                        if showCategories {
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
                            .accessibilityLabel("Categories: Browse tasks by category")
                        }
                    }

                    // MARK: - Settings Section
                    if !filteredRoutes.isEmpty {
                        sectionHeader("Settings")
                            .padding(.top, DesignSystem.Spacing.sm)

                        ForEach(filteredRoutes) { route in
                            NavigationLink {
                                route.destination
                            } label: {
                                ProfileCard(
                                    icon: route.icon,
                                    iconColor: route.iconColor,
                                    title: route.title,
                                    subtitle: route.subtitle
                                )
                            }
                            .accessibilityIdentifier(route.accessibilityIdentifier)
                            .accessibilityLabel("\(route.title): \(route.subtitle)")
                        }
                    }

                    // MARK: - Empty Search State
                    if isSearching && !showLists && !showCategories && filteredRoutes.isEmpty {
                        ContentUnavailableView.search(text: trimmedSearch)
                    }

                    // MARK: - App Footer
                    if !isSearching {
                        Spacer(minLength: DesignSystem.Spacing.xxl)
                        appInfoFooter
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(Color.adaptiveBackground)
            .searchable(text: $searchText, prompt: "Search")
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: ContentView.ProfileDestination.self) { destination in
                switch destination {
                case .lists:
                    ListsView()
                }
            }
        }
    }

    private func matchesSearch(_ title: String, _ subtitle: String) -> Bool {
        guard !trimmedSearch.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(trimmedSearch)
            || subtitle.localizedCaseInsensitiveContains(trimmedSearch)
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
            if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
               let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
               let iconName = iconFiles.last,
               let uiImage = UIImage(named: iconName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                    .opacity(0.8)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color.Lazyflow.accent)
                    .opacity(0.8)
            }

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
