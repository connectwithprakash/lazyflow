import SwiftUI

/// View showing all task categories (system and custom)
struct CategoriesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = CategoriesViewModel()
    @StateObject private var categoryService = CategoryService.shared
    @State private var showManageCategories = false

    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: No NavigationStack (provided by split view)
            categoriesContent
                .navigationTitle("Categories")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        manageButton
                    }
                }
                .sheet(isPresented: $showManageCategories) {
                    NavigationStack {
                        CategoryManagementView()
                    }
                }
        } else {
            // iPhone: Full NavigationStack
            NavigationStack {
                categoriesContent
                    .navigationTitle("Categories")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            manageButton
                        }
                    }
                    .sheet(isPresented: $showManageCategories) {
                        NavigationStack {
                            CategoryManagementView()
                        }
                    }
            }
        }
    }

    private var manageButton: some View {
        Button {
            showManageCategories = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.body)
                .foregroundColor(Color.Lazyflow.accent)
        }
        .accessibilityLabel("Manage categories")
    }

    private var categoriesContent: some View {
        ZStack {
            Color.adaptiveBackground
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.lg) {
                    // System Categories
                    systemCategoriesSection

                    // Custom Categories
                    customCategoriesSection

                    Spacer(minLength: 100)
                }
                .padding(.top)
            }
        }
    }

    // MARK: - System Categories Section

    private var systemCategoriesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("System Categories")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)
                .padding(.horizontal)

            VStack(spacing: 1) {
                ForEach(TaskCategory.allCases) { category in
                    NavigationLink {
                        CategoryDetailView(systemCategory: category)
                    } label: {
                        CategoryListRow(
                            icon: category.iconName,
                            title: category.displayName,
                            count: viewModel.taskCount(for: category),
                            color: category.color
                        )
                    }
                }
            }
            .background(Color.adaptiveSurface)
            .cornerRadius(DesignSystem.CornerRadius.large)
            .padding(.horizontal)
        }
    }

    // MARK: - Custom Categories Section

    private var customCategoriesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Custom Categories")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)

                Spacer()

                Button {
                    showManageCategories = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color.Lazyflow.accent)
                }
            }
            .padding(.horizontal)

            if categoryService.categories.isEmpty {
                emptyCustomCategoriesView
            } else {
                VStack(spacing: 1) {
                    ForEach(categoryService.categories) { category in
                        NavigationLink {
                            CategoryDetailView(customCategory: category)
                        } label: {
                            CategoryListRow(
                                icon: category.iconName,
                                title: category.displayName,
                                count: viewModel.taskCount(for: category.id),
                                color: category.color
                            )
                        }
                    }
                }
                .background(Color.adaptiveSurface)
                .cornerRadius(DesignSystem.CornerRadius.large)
                .padding(.horizontal)
            }
        }
    }

    private var emptyCustomCategoriesView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "tag")
                .font(.system(size: 32))
                .foregroundColor(Color.Lazyflow.textTertiary)

            Text("No custom categories yet")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)

            Button("Create Category") {
                showManageCategories = true
            }
            .font(DesignSystem.Typography.subheadline)
            .foregroundColor(Color.Lazyflow.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xxl)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .padding(.horizontal)
    }
}

// MARK: - Category List Row

private struct CategoryListRow: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28)

            Text(title)
                .font(DesignSystem.Typography.body)
                .foregroundColor(Color.Lazyflow.textPrimary)

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.Lazyflow.textTertiary)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    CategoriesView()
}
