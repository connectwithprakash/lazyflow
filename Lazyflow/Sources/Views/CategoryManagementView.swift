import SwiftUI

/// View for managing custom categories
struct CategoryManagementView: View {
    @StateObject private var categoryService = CategoryService.shared
    @State private var showAddSheet = false
    @State private var categoryToEdit: CustomCategory?
    @State private var showDeleteConfirmation = false
    @State private var categoryToDelete: CustomCategory?

    var body: some View {
        List {
            // System Categories Section (read-only)
            Section {
                ForEach(TaskCategory.allCases) { category in
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: category.iconName)
                            .foregroundColor(category.color)
                            .frame(width: 28)

                        Text(category.displayName)
                            .foregroundColor(Color.Lazyflow.textPrimary)

                        Spacer()

                        Text("System")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textTertiary)
                    }
                }
            } header: {
                Text("System Categories")
            } footer: {
                Text("System categories cannot be modified or deleted.")
            }

            // Custom Categories Section
            Section {
                if categoryService.categories.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "tag.slash")
                                .font(.system(size: 32))
                                .foregroundColor(Color.Lazyflow.textTertiary)
                            Text("No custom categories")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                            Text("Tap + to create one")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textTertiary)
                        }
                        .padding(.vertical, DesignSystem.Spacing.lg)
                        Spacer()
                    }
                } else {
                    ForEach(categoryService.categories) { category in
                        CategoryRow(category: category, onEdit: {
                            categoryToEdit = category
                        })
                    }
                    .onDelete(perform: deleteCategories)
                    .onMove(perform: moveCategories)
                }
            } header: {
                HStack {
                    Text("Custom Categories")
                    Spacer()
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color.Lazyflow.accent)
                    }
                }
            } footer: {
                if !categoryService.categories.isEmpty {
                    Text("Tap to edit, swipe to delete, or drag to reorder.")
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            CategoryEditSheet(mode: .add, onSave: { name, colorHex, iconName in
                categoryService.createCategory(name: name, colorHex: colorHex, iconName: iconName)
            })
        }
        .sheet(item: $categoryToEdit) { category in
            CategoryEditSheet(mode: .edit(category), onSave: { name, colorHex, iconName in
                let updated = category.updated(name: name, colorHex: colorHex, iconName: iconName)
                categoryService.updateCategory(updated)
            })
        }
        .alert("Delete Category?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let category = categoryToDelete {
                    categoryService.deleteCategory(category)
                }
            }
        } message: {
            if let category = categoryToDelete {
                Text("Are you sure you want to delete \"\(category.name)\"? Tasks using this category will be set to Uncategorized.")
            }
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            let category = categoryService.categories[index]
            categoryToDelete = category
            showDeleteConfirmation = true
        }
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var categories = categoryService.categories
        categories.move(fromOffsets: source, toOffset: destination)
        categoryService.reorderCategories(categories)
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: CustomCategory
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: category.iconName)
                    .foregroundColor(category.color)
                    .frame(width: 28)

                Text(category.displayName)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Spacer()

                Circle()
                    .fill(category.color)
                    .frame(width: 12, height: 12)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
        }
    }
}

// MARK: - Category Edit Sheet

struct CategoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case add
        case edit(CustomCategory)

        var title: String {
            switch self {
            case .add: return "New Category"
            case .edit: return "Edit Category"
            }
        }

        var buttonTitle: String {
            switch self {
            case .add: return "Create"
            case .edit: return "Save"
            }
        }
    }

    let mode: Mode
    let onSave: (String, String, String) -> Void

    @State private var name: String = ""
    @State private var selectedColorHex: String = "#808080"
    @State private var selectedIconName: String = "tag.fill"

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var nameValidationError: String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return nil }

        if CategoryService.shared.conflictsWithSystemCategory(trimmedName) {
            return "This name conflicts with a system category"
        }

        let excludeID: UUID? = if case .edit(let cat) = mode { cat.id } else { nil }
        if CategoryService.shared.categoryNameExists(trimmedName, excludingID: excludeID) {
            return "A category with this name already exists"
        }

        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name Section
                Section {
                    TextField("Category Name", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Name")
                } footer: {
                    if let error = nameValidationError {
                        Text(error)
                            .foregroundColor(Color.Lazyflow.error)
                    }
                }

                // Color Section
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(CustomCategory.availableColors, id: \.self) { colorHex in
                            Button {
                                selectedColorHex = colorHex
                            } label: {
                                Circle()
                                    .fill(Color(hex: colorHex) ?? .gray)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.Lazyflow.textPrimary, lineWidth: selectedColorHex == colorHex ? 2 : 0)
                                    )
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .opacity(selectedColorHex == colorHex ? 1 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }

                // Icon Section
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(CustomCategory.availableIcons, id: \.self) { iconName in
                            Button {
                                selectedIconName = iconName
                            } label: {
                                Image(systemName: iconName)
                                    .font(.system(size: 18))
                                    .frame(width: 36, height: 36)
                                    .foregroundColor(selectedIconName == iconName ? .white : (Color(hex: selectedColorHex) ?? .gray))
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIconName == iconName ? (Color(hex: selectedColorHex) ?? .gray) : Color.secondary.opacity(0.15))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }

                // Preview Section
                Section("Preview") {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: selectedIconName)
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: selectedColorHex) ?? .gray)
                            .frame(width: 28)

                        Text(name.isEmpty ? "Category Name" : name)
                            .foregroundColor(name.isEmpty ? Color.Lazyflow.textTertiary : Color.Lazyflow.textPrimary)

                        Spacer()

                        Circle()
                            .fill(Color(hex: selectedColorHex) ?? .gray)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.buttonTitle) {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), selectedColorHex, selectedIconName)
                        dismiss()
                    }
                    .disabled(!isValid || nameValidationError != nil)
                }
            }
            .onAppear {
                if case .edit(let category) = mode {
                    name = category.name
                    selectedColorHex = category.colorHex
                    selectedIconName = category.iconName
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CategoryManagementView()
    }
}
