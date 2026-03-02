import SwiftUI

struct BatchAnalysisReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var results: [BatchAnalysisResult]
    let onApply: () -> Void

    private var selectedCount: Int {
        results.filter { $0.isSelected }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(results.count) task\(results.count == 1 ? "" : "s") analyzed")
                        .font(DesignSystem.Typography.footnote)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach($results) { $result in
                        BatchAnalysisResultRow(result: $result)
                    }
                } header: {
                    HStack {
                        Text("Proposed Changes")
                        Spacer()
                        Button(selectedCount == results.count ? "Deselect All" : "Select All") {
                            let newValue = selectedCount != results.count
                            for i in results.indices {
                                results[i].isSelected = newValue
                            }
                        }
                        .font(DesignSystem.Typography.caption1)
                    }
                }
            }
            .navigationTitle("Review Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply \(selectedCount)") {
                        onApply()
                    }
                    .disabled(selectedCount == 0)
                }
            }
        }
    }
}

// MARK: - Batch Analysis Result Row

struct BatchAnalysisResultRow: View {
    @Binding var result: BatchAnalysisResult

    // Category display helpers
    private var categoryDisplayName: String {
        if let customID = result.analysis.suggestedCustomCategoryID,
           let custom = CategoryService.shared.getCategory(byID: customID) {
            return custom.displayName
        }
        return result.analysis.suggestedCategory.displayName
    }

    private var categoryDisplayIcon: String {
        if let customID = result.analysis.suggestedCustomCategoryID,
           let custom = CategoryService.shared.getCategory(byID: customID) {
            return custom.iconName
        }
        return result.analysis.suggestedCategory.iconName
    }

    private var categoryDisplayColor: Color {
        if let customID = result.analysis.suggestedCustomCategoryID,
           let custom = CategoryService.shared.getCategory(byID: customID) {
            return custom.color
        }
        return result.analysis.suggestedCategory.color
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Checkbox
            Button {
                result.isSelected.toggle()
            } label: {
                Image(systemName: result.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(result.isSelected ? Color.Lazyflow.accent : Color.Lazyflow.textTertiary)
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)

            // Task info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Original title
                Text(result.task.title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                // Refined title (if different)
                if result.hasTitleChange, let refinedTitle = result.analysis.refinedTitle {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 10))
                            .foregroundColor(Color.Lazyflow.textTertiary)
                        Text(refinedTitle)
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(Color.orange)
                            .lineLimit(1)
                    }
                }

                // Suggested changes
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Category
                    Label {
                        Text(categoryDisplayName)
                            .font(DesignSystem.Typography.caption2)
                    } icon: {
                        Image(systemName: categoryDisplayIcon)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(categoryDisplayColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(categoryDisplayColor.opacity(0.15))
                    .cornerRadius(4)

                    // Priority (if not none)
                    if result.analysis.suggestedPriority != .none {
                        Label {
                            Text(result.analysis.suggestedPriority.displayName)
                                .font(DesignSystem.Typography.caption2)
                        } icon: {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(result.analysis.suggestedPriority.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(result.analysis.suggestedPriority.color.opacity(0.15))
                        .cornerRadius(4)
                    }

                    // Duration
                    Label {
                        Text("\(result.analysis.estimatedMinutes)m")
                            .font(DesignSystem.Typography.caption2)
                    } icon: {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(Color.Lazyflow.textSecondary)
                }

                // Description preview (if any)
                if let description = result.analysis.suggestedDescription, !description.isEmpty {
                    Text(description)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textTertiary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            result.isSelected.toggle()
        }
    }
}
