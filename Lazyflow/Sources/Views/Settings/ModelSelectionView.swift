import SwiftUI

/// View for selecting a model from available models, grouped by provider
struct ModelSelectionView: View {
    let models: [AvailableModel]
    @Binding var selectedModelId: String
    @Environment(\.dismiss) private var dismiss
    @State private var showFreeOnly = false
    @State private var selectedModelForDetail: AvailableModel?
    @State private var searchText = ""

    /// Models filtered by search and free filter, grouped by provider
    private var groupedModels: [(provider: String, models: [AvailableModel])] {
        var filtered = models

        // Apply free filter
        if showFreeOnly {
            filtered = filtered.filter { $0.isFree }
        }

        // Apply search filter
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            filtered = filtered.filter {
                $0.name.lowercased().contains(search) ||
                $0.id.lowercased().contains(search) ||
                ($0.description?.lowercased().contains(search) ?? false)
            }
        }

        let grouped = Dictionary(grouping: filtered) { $0.provider ?? "Other" }
        return grouped.sorted { $0.key < $1.key }.map { (provider: $0.key, models: $0.value) }
    }

    var body: some View {
        List {
            // Free filter toggle (only show if there are both free and paid models)
            let freeCount = models.filter { $0.isFree }.count
            if freeCount > 0 && freeCount < models.count {
                Section {
                    Toggle("Show Free Models Only", isOn: $showFreeOnly)
                } footer: {
                    Text("\(freeCount) of \(models.count) models are free")
                }
            }

            // Grouped models
            ForEach(groupedModels, id: \.provider) { group in
                Section(group.provider) {
                    ForEach(group.models) { model in
                        Button {
                            selectedModelId = model.id
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(model.displayName)
                                            .foregroundColor(Color.Lazyflow.textPrimary)
                                        if model.isFree {
                                            Text("FREE")
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.Lazyflow.success)
                                                .cornerRadius(3)
                                        }
                                    }
                                    if let desc = model.description {
                                        Text(desc)
                                            .font(DesignSystem.Typography.caption2)
                                            .foregroundColor(Color.Lazyflow.textTertiary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                // Info indicator (visual hint for swipe)
                                if model.description != nil {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.Lazyflow.textTertiary.opacity(0.6))
                                }

                                // Checkmark for selected model
                                if model.id == selectedModelId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.Lazyflow.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if model.description != nil {
                                Button {
                                    selectedModelForDetail = model
                                } label: {
                                    Label("Info", systemImage: "info.circle")
                                }
                                .tint(Color.Lazyflow.accent)
                            }
                        }
                    }
                }
            }

            // Hint about swipe for details
            if models.contains(where: { $0.description != nil }) {
                Section {
                } footer: {
                    Text("Swipe left on a model for more details")
                        .font(DesignSystem.Typography.caption2)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search models")
        .navigationTitle("Select Model")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedModelForDetail) { model in
            ModelDetailSheet(model: model)
        }
    }
}

/// Sheet showing model details
struct ModelDetailSheet: View {
    let model: AvailableModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Model name
                    HStack {
                        Text(model.displayName)
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                        if model.isFree {
                            Text("FREE")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.Lazyflow.success)
                                .cornerRadius(4)
                        }
                    }

                    // Provider
                    if let provider = model.provider {
                        HStack {
                            Text("Provider:")
                                .foregroundColor(Color.Lazyflow.textSecondary)
                            Text(provider)
                        }
                        .font(DesignSystem.Typography.subheadline)
                    }

                    // Model ID
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model ID")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                        Text(model.id)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(Color.Lazyflow.textPrimary)
                    }

                    // Description
                    if let description = model.description {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                            Text(description)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(Color.Lazyflow.textPrimary)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Model Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
