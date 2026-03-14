import SwiftUI
import LazyflowCore
import LazyflowUI

// MARK: - Batch Analysis Result Model

struct BatchAnalysisResult: Identifiable {
    let id = UUID()
    let task: Task
    let analysis: TaskAnalysis
    var isSelected: Bool = true

    /// Check if title was changed by AI
    var hasTitleChange: Bool {
        guard let refined = analysis.refinedTitle else { return false }
        return refined != task.title
    }
}

// MARK: - AI Settings View

struct AISettingsView: View {
    private var llmService = LLMService.shared
    private var taskService = TaskService.shared
    @AppStorage(AppConstants.StorageKey.aiAutoSuggest) private var aiAutoSuggest: Bool = true
    @AppStorage(AppConstants.StorageKey.aiEstimateDuration) private var aiEstimateDuration: Bool = true
    @AppStorage(AppConstants.StorageKey.aiSuggestPriority) private var aiSuggestPriority: Bool = true

    @State private var isBatchAnalyzing = false
    @State private var batchAnalysisProgress: Int = 0
    @State private var batchAnalysisTotal: Int = 0
    @State private var showBatchReviewSheet = false
    @State private var batchResults: [BatchAnalysisResult] = []
    @State private var configProviderType: LLMProviderType?

    var body: some View {
            Form {
                // Provider Selection Section
                Section {
                    ForEach(LLMProviderType.allCases) { provider in
                        providerRow(for: provider)
                    }
                } header: {
                    Text("AI Provider")
                } footer: {
                    providerFooterText
                }

                // AI Features Section
                Section("AI Features") {
                    Toggle(isOn: $aiAutoSuggest) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Suggest")
                            Text("Show AI suggestions when creating tasks")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }

                    Toggle(isOn: $aiEstimateDuration) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Estimate Duration")
                            Text("AI estimates how long tasks will take")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }

                    Toggle(isOn: $aiSuggestPriority) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Suggest Priority")
                            Text("AI suggests task priority levels")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }
                }
                .disabled(!llmService.isReady)

                // Batch Analysis Section
                Section {
                    Button {
                        runBatchAnalysis()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(Color.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Analyze Uncategorized Tasks")
                                    .foregroundColor(Color.Lazyflow.textPrimary)
                                Text("\(uncategorizedTaskCount) tasks need categorization")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }
                            Spacer()
                            if isBatchAnalyzing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!llmService.isReady || isBatchAnalyzing || uncategorizedTaskCount == 0)

                    if isBatchAnalyzing {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            HStack {
                                Text("Analyzing...")
                                    .font(DesignSystem.Typography.footnote)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                                Spacer()
                                Text("\(batchAnalysisProgress)/\(batchAnalysisTotal)")
                                    .font(DesignSystem.Typography.footnote)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }
                            ProgressView(value: Double(batchAnalysisProgress), total: Double(batchAnalysisTotal))
                                .tint(Color.purple)
                        }
                    }
                } header: {
                    Text("Batch Analysis")
                } footer: {
                    Text("Automatically categorize and estimate duration for tasks without a category.")
                }
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showBatchReviewSheet) {
                BatchAnalysisReviewSheet(
                    results: $batchResults,
                    onApply: applyBatchResults
                )
            }
            .sheet(item: $configProviderType) { providerType in
                ProviderConfigurationSheet(providerType: providerType)
            }
    }

    // MARK: - Provider UI

    @ViewBuilder
    private func providerRow(for provider: LLMProviderType) -> some View {
        Button {
            if provider == .apple {
                llmService.selectedProvider = provider
            } else if llmService.availableProviders.contains(provider) {
                if llmService.selectedProvider == provider {
                    // Already selected - tap again to edit
                    configProviderType = provider
                } else {
                    // Select this provider
                    llmService.selectedProvider = provider
                }
            } else {
                // Need to configure first
                configProviderType = provider
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: provider.iconName)
                    .font(.title2)
                    .foregroundColor(llmService.selectedProvider == provider ? Color.Lazyflow.accent : Color.Lazyflow.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(provider.displayName)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(Color.Lazyflow.textPrimary)

                        // Show "External" badge for providers that send data externally
                        if provider.isExternal {
                            Text("External")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.8))
                                .cornerRadius(4)
                        }
                    }

                    Text(provider.description)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                Spacer()

                // Selection indicator
                if llmService.selectedProvider == provider {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.Lazyflow.accent)
                } else if llmService.availableProviders.contains(provider) {
                    Image(systemName: "circle")
                        .foregroundColor(Color.Lazyflow.textTertiary)
                } else if provider != .apple {
                    Text("Configure")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.accent)
                }

                // Edit chevron for configured non-Apple providers
                if provider != .apple && llmService.availableProviders.contains(provider) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Lazyflow.textTertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if provider != .apple && llmService.availableProviders.contains(provider) {
                Button {
                    configProviderType = provider
                } label: {
                    Label("Edit Configuration", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    llmService.removeOpenResponsesProvider(type: provider)
                } label: {
                    Label("Remove Provider", systemImage: "trash")
                }
            }
        }
    }

    private var providerFooterText: Text {
        let provider = llmService.selectedProvider
        switch provider {
        case .apple:
            return Text("Apple Intelligence runs entirely on your device. No data leaves your device. Requires iOS 18.4 or later.")
        case .ollama:
            return Text("Ollama runs locally on your Mac. Your data stays on your local network.")
        case .custom:
            return Text("⚠️ Custom endpoints may send your task data to external servers. Ensure you trust the endpoint provider.")
        }
    }

    // MARK: - Computed Properties

    private var uncategorizedTaskCount: Int {
        taskService.tasks.filter { $0.category == .uncategorized && !$0.isCompleted }.count
    }

    // MARK: - Batch Analysis

    private func runBatchAnalysis() {
        let uncategorizedTasks = taskService.tasks.filter { $0.category == .uncategorized && !$0.isCompleted }
        guard !uncategorizedTasks.isEmpty else { return }

        isBatchAnalyzing = true
        batchAnalysisProgress = 0
        batchAnalysisTotal = uncategorizedTasks.count
        batchResults = []

        _Concurrency.Task {
            var results: [BatchAnalysisResult] = []

            for task in uncategorizedTasks {
                do {
                    let analysis = try await llmService.analyzeTask(task)

                    // Collect the result for review (don't apply yet)
                    await MainActor.run {
                        results.append(BatchAnalysisResult(task: task, analysis: analysis))
                        batchAnalysisProgress += 1
                    }
                } catch {
                    await MainActor.run {
                        batchAnalysisProgress += 1
                    }
                }

                // Small delay to avoid rate limiting
                try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }

            await MainActor.run {
                isBatchAnalyzing = false
                batchResults = results
                if !results.isEmpty {
                    showBatchReviewSheet = true
                }
            }
        }
    }

    private func applyBatchResults() {
        let selectedResults = batchResults.filter { $0.isSelected }

        for result in selectedResults {
            let updatedTask = result.task.updated(
                title: result.analysis.refinedTitle,
                notes: result.analysis.suggestedDescription,
                priority: result.analysis.suggestedPriority,
                category: result.analysis.suggestedCategory,
                customCategoryID: result.analysis.suggestedCustomCategoryID,
                estimatedDuration: TimeInterval(result.analysis.estimatedMinutes * 60)
            )
            taskService.updateTask(updatedTask)
        }

        showBatchReviewSheet = false
        batchResults = []
    }
}
